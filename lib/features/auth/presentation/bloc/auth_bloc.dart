
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/user_presence_service.dart';
import '../../../../services/fcm_service.dart';
import '../../../../services/cell_subscription_service.dart';
import '../../../../services/heatmap_service.dart';
import '../../../../services/supabase_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignInRequested>(_onSignInRequested);
    on<SignUpUserRequested>(_onSignUpUserRequested);
    on<SignUpDriverRequested>(_onSignUpDriverRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.getCurrentUser();
    await result.fold(
      (error) async => emit(AuthUnauthenticated()),
      (user) async {
        if (user == null) {
          emit(AuthUnauthenticated());
        } else if (user.isBlocked) {
          
          await _authRepository.signOut();
          emit(const AuthError('errorUserBlocked'));
        } else if (user.role == 'driver') {
          final verifiedResult = await _authRepository.getDriverIsVerified(user.id);
          final isVerified = verifiedResult.getOrElse(() => false);
          if (isVerified) {
            emit(AuthAuthenticated(user));
          } else {
            emit(AuthDriverPending(user));
          }
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.signIn(
      email: event.email,
      password: event.password,
    );
    await result.fold(
      (error) async => emit(AuthError(error)),
      (user) async {
        await _storeFcmToken(user.id);
        if (user.role == 'driver') {
          final verifiedResult = await _authRepository.getDriverIsVerified(user.id);
          final isVerified = verifiedResult.getOrElse(() => false);
          if (isVerified) {
            emit(AuthAuthenticated(user));
          } else {
            emit(AuthDriverPending(user));
          }
        } else {
          emit(AuthAuthenticated(user));
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
            .update({'fcm_token': token})
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint('AuthBloc: FCM token store failed — $e');
    }
  }

  Future<void> _onSignUpUserRequested(
    SignUpUserRequested event,
    Emitter<AuthState> emit,
  ) async {
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
        await _storeFcmToken(user.id);
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignUpDriverRequested(
    SignUpDriverRequested event,
    Emitter<AuthState> emit,
  ) async {
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
    result.fold(
      (error) => emit(AuthError(error)),
      (user) => emit(AuthDriverPending(user)),
    );
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    await UserPresenceService.instance.stopBroadcasting();
    await CellSubscriptionService.instance.dispose();
    HeatmapService.instance.dispose();
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
