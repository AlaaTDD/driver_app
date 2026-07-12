import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/user_presence_service.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/logout_coordinator.dart';
import '../../../../core/models/driver_profile_model.dart' show DriverAccountStatus;
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  // اشتراك Realtime دائم على account_status للسائق الحالي، يبقى فعّالاً
  // طوال الجلسة المفتوحة وليس فقط عند CheckAuthStatus/SignInRequested.
  // انظر MASTER_PLAN.md القسم 4، المرحلة ج، البند 10.
  StreamSubscription<({DriverAccountStatus status, String? revisionReason})>?
      _driverStatusSubscription;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignInRequested>(_onSignInRequested);
    on<SignUpUserRequested>(_onSignUpUserRequested);
    on<SignUpDriverRequested>(_onSignUpDriverRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<DriverAccountStatusChanged>(_onDriverAccountStatusChanged);
    on<ResetAuth>((_, emit) {
      _driverStatusSubscription?.cancel();
      _driverStatusSubscription = null;
      emit(AuthUnauthenticated());
    });
  }

  /// يبدأ (أو يعيد بدء) اشتراك Realtime دائم لسائق معين، ويحوّل كل
  /// حدث إلى حدث داخلي `add()` على الـ bloc نفسه، ليمر عبر مسار emit الطبيعي.
  void _startWatchingDriverStatus(UserEntity user) {
    _driverStatusSubscription?.cancel();
    _driverStatusSubscription =
        _authRepository.watchDriverAccountStatus(user.id).listen(
      (event) => add(DriverAccountStatusChanged(user, event.status, event.revisionReason)),
      onError: (Object e, StackTrace st) {
        AppLogger.error('AuthBloc: driver status watch failed', tag: 'AuthBloc', error: e, stackTrace: st);
      },
    );
  }

  Future<void> _onDriverAccountStatusChanged(
    DriverAccountStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    switch (event.status) {
      case DriverAccountStatus.blocked:
        emit(AuthDriverBlocked(event.user, reason: event.revisionReason));
      case DriverAccountStatus.pendingReview:
        emit(AuthDriverPending(event.user, revisionReason: event.revisionReason));
      case DriverAccountStatus.underReview:
        // السائق أرسل تعديلاته فعلاً وينتظر مراجعة الأدمن — حالة قراءة فقط،
        // مصدرها account_status من الـ DB حصراً. انظر MASTER_PLAN.md القسم 4.4.
        emit(AuthDriverUnderReview(event.user));
      case DriverAccountStatus.approved:
        try {
          await UserPresenceService.instance.startBroadcasting();
        } catch (_) {
          // لا يمنع الاعتماد لو فشل البث فقط، بنفس المنطق الموجود في بقية الملف.
        }
        emit(AuthAuthenticated(event.user));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    final result = await _authRepository.getCurrentUser();
    await result.fold(
      (error) async {
        // [AUTH-10 FIX] Network error must NOT log the user out
        if (error == 'errorNoInternet') {
          emit(const AuthError('errorNoInternet'));
        } else {
          emit(AuthUnauthenticated());
        }
      },
      (user) async {
        if (user == null) {
          emit(AuthUnauthenticated());
        } else if (user.isBlocked) {
          await _authRepository.signOut();
          emit(const AuthError('errorUserBlocked'));
        } else if (user.role == 'driver') {
          try {
            // [المرحلة ج، البند 10] يبدأ اشتراك Realtime دائم بدلاً من
            // الفحص لمرة واحدة؛ القيمة الأولية تصل فوراً عبر emitCurrent()
            // داخل watchDriverAccountStatus، ثم يبقى الاشتراك مفتوحاً طوال الجلسة.
            _startWatchingDriverStatus(user);
          } catch (e, st) {
            AppLogger.error('AuthBloc: checkAuth driver failed', tag: 'AuthBloc', error: e, stackTrace: st);
            emit(const AuthError('errorUnexpected'));
          }
        } else {
          try {
            await UserPresenceService.instance.startBroadcasting();
            emit(AuthAuthenticated(user));
          } catch (e, st) {
            AppLogger.error('AuthBloc: checkAuth user failed', tag: 'AuthBloc', error: e, stackTrace: st);
            emit(AuthAuthenticated(user)); // still auth even if presence fails
          }
        }
      },
    );
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    final result = await _authRepository.signIn(
      email: event.email,
      password: event.password,
    );
    await result.fold(
      (error) async => emit(AuthError(error)),
      (user) async {
        // [AUTH-26 FIX] Check isActive after successful login
        if (!user.isActive) {
          await _authRepository.signOut();
          emit(const AuthError('errorUserBlocked'));
          return;
        }
        try {
          await _storeFcmToken(user.id);
          if (user.role == 'driver') {
            // [المرحلة ج، البند 10] نفس المنطق: اشتراك دائم بدل فحص لمرة واحدة.
            _startWatchingDriverStatus(user);
          } else {
            await UserPresenceService.instance.startBroadcasting();
            emit(AuthAuthenticated(user));
          }
        } catch (e, st) {
          AppLogger.error('AuthBloc: signIn post-login failed', tag: 'AuthBloc', error: e, stackTrace: st);
          emit(const AuthError('errorUnexpected'));
        }
      },
    );
  }

  Future<void> _storeFcmToken(String userId) async {
    try {
      final token = await FCMService().getToken();
      if (token != null) {
        await SupabaseService.client
            .from('users')
            .update({'fcm_token': token}).eq('id', userId);
      }
    } catch (e) {
      AppLogger.debug('AuthBloc: FCM token store failed — $e');
    }
  }

  Future<void> _onSignUpUserRequested(
    SignUpUserRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    final result = await _authRepository.signUpUser(
      name: event.name,
      phone: event.phone,
      email: event.email,
      password: event.password,
    );
    await result.fold(
      (error) async => emit(AuthError(error)),
      (user) async {
        try {
          await _storeFcmToken(user.id);
          await UserPresenceService.instance.startBroadcasting();
          emit(AuthAuthenticated(user));
        } catch (e, st) {
          AppLogger.error('AuthBloc: signUpUser post-register failed', tag: 'AuthBloc', error: e, stackTrace: st);
          emit(AuthAuthenticated(user)); // still auth even if FCM/presence fails
        }
      },
    );
  }

  Future<void> _onSignUpDriverRequested(
    SignUpDriverRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    final result = await _authRepository.signUpDriver(
      name: event.name,
      phone: event.phone,
      email: event.email,
      password: event.password,
      nationalId: event.nationalId,
      nationalIdImageUrl: event.nationalIdImageUrl,
      licenseNumber: event.licenseNumber,
      licenseImageUrl: event.licenseImageUrl,
      criminalRecordUrl: event.criminalRecordUrl,
      vehicleCategory: event.vehicleCategory,
      vehicleBrand: event.vehicleBrand,
      vehicleModel: event.vehicleModel,
      vehicleYear: event.vehicleYear,
      vehicleColor: event.vehicleColor,
      vehiclePlate: event.vehiclePlate,
      vehicleImageUrl: event.vehicleImageUrl,
    );
    await result.fold(
      (error) async => emit(AuthError(error)),
      (user) async {
        try {
          await _storeFcmToken(user.id);
          emit(AuthDriverPending(user));
        } catch (e, st) {
          AppLogger.error('AuthBloc: signUpDriver post-register failed', tag: 'AuthBloc', error: e, stackTrace: st);
          emit(AuthDriverPending(user)); // still navigate even if FCM fails
        }
      },
    );
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _driverStatusSubscription?.cancel();
    _driverStatusSubscription = null;
    await LogoutCoordinator.instance.performLogout();
    final result = await _authRepository.signOut();
    result.fold(
      (error) => emit(AuthError(error)),
      (_) => emit(AuthUnauthenticated()),
    );
  }

  @override
  Future<void> close() {
    _driverStatusSubscription?.cancel();
    return super.close();
  }

  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _authRepository.updateProfile(
      userId: event.userId,
      name: event.name,
      avatarUrl: event.avatarUrl,
    );
    result.fold(
      (error) => emit(AuthError(error)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }
}
