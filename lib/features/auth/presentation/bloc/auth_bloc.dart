import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/user_presence_service.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/logout_coordinator.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignInRequested>(_onSignInRequested);
    on<SignUpUserRequested>(_onSignUpUserRequested);
    on<SignUpDriverRequested>(_onSignUpDriverRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<ResetAuth>((_, emit) => emit(AuthUnauthenticated()));
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
            final verifiedResult =
                await _authRepository.getDriverIsVerified(user.id);
            final isVerified = verifiedResult.getOrElse(() => false);
            if (isVerified) {
              await UserPresenceService.instance.startBroadcasting();
              emit(AuthAuthenticated(user));
            } else {
              emit(AuthDriverPending(user));
            }
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
            final verifiedResult =
                await _authRepository.getDriverIsVerified(user.id);
            final isVerified = verifiedResult.getOrElse(() => false);
            if (isVerified) {
              await UserPresenceService.instance.startBroadcasting();
              emit(AuthAuthenticated(user));
            } else {
              emit(AuthDriverPending(user));
            }
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
      vehicleType: event.vehicleType,
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
    await LogoutCoordinator.instance.performLogout();
    final result = await _authRepository.signOut();
    result.fold(
      (error) => emit(AuthError(error)),
      (_) => emit(AuthUnauthenticated()),
    );
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
