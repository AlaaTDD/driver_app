import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/r2_storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:snapix/core/utils/app_logger.dart';

String _mapError(Object e) {
  // [APP-H-06 FIXED] Log only exception type + status code — never the full
  // toString() which may include the user's email address or credentials.
  final safeLog = e is AuthException
      ? 'AuthException(code=${e.code})'
      : e.runtimeType.toString();
  AppLogger.error('AUTH ERROR [$safeLog]');
  // [AUTH-APP-EX FIX] AppException subclasses (ServerException, ValidationException,
  // StorageException, etc.) already carry a valid i18n error key in .message.
  // Return it directly instead of trying to match toString() output.
  if (e is AppException) return e.message;
  final msg = e.toString().toLowerCase();
  // [AUTH-25 FIX] TimeoutException → treat as network error, not unexpected
  if (msg.contains('timeoutexception') || msg.contains('future not completed')) {
    return 'errorNoInternet';
  }
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid_credentials')) {
    return 'errorInvalidCredentials';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return 'errorEmailRegistered';
  }
  if (msg.contains('email not confirmed')) {
    return 'errorConfirmEmail';
  }
  if (msg.contains('password should be at least')) {
    return 'errorPasswordLength';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection')) {
    return 'errorNoInternet';
  }
  if (msg.contains('too many requests') || msg.contains('rate limit')) {
    return 'errorRateLimit';
  }
  if (msg.contains('row not found') || msg.contains('pgrst116')) {
    return 'errorUserNotFound';
  }
  if ((msg.contains('phone') || msg.contains('phone_number')) &&
      (msg.contains('unique') || msg.contains('duplicate') || msg.contains('already'))) {
    return 'errorPhoneRegistered';
  }
  // [AUTH-500 FIX] Supabase returns status=500 when the on-auth-user-created
  // DB trigger fails (e.g. NOT NULL violation on users.phone or users.name).
  // Map this to a clear error so the user gets a meaningful message.
  if (msg.contains('status: 500') || msg.contains('status=500') ||
      msg.contains('"status":500') || msg.contains('statuscode: 500')) {
    return 'errorCreateAccountFailed';
  }
  return 'errorUnexpected';
}

class AuthRepositoryImpl implements AuthRepository {
  final R2StorageService _r2StorageService;

  AuthRepositoryImpl(this._r2StorageService);

  @override
  Future<Either<String, UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseService.client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 15));

      final user = response.user;
      if (user == null) {
        return const Left('errorLoginFailed');
      }

      Map<String, dynamic>? userData;
      try {
        userData = await SupabaseService.client
            .from('users')
            .select(
                'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
            .eq('id', user.id)
            .single()
            .timeout(const Duration(seconds: 15));
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST116') {
          // Auto-recovery: Create missing profile using auth metadata
          final meta = user.userMetadata ?? {};
          if (meta['role'] == 'driver') {
            await SupabaseService.client.auth.signOut();
            return const Left('errorDriverProfileIncomplete');
          }
          userData = await SupabaseService.client
              .from('users')
              .upsert({
                'id': user.id,
                'name': meta['name'] ?? 'User',
                'phone': meta['phone'] ?? '',
                'email': user.email ?? email,
                'role': 'user',
                'rating': 0.00,
                'total_trips': 0,
                'language': 'ar',
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single()
              .timeout(const Duration(seconds: 15));
        } else {
          rethrow;
        }
      }

      if (userData['is_blocked'] == true) {
        await SupabaseService.client.auth.signOut();
        return const Left('errorUserBlocked');
      }

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, UserEntity>> signUpUser({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseService.client.auth
          .signUp(
            email: email,
            password: password,
            data: {
              'name': name,
              'phone': phone,
              'role': 'user',
            },
          )
          .timeout(const Duration(seconds: 15));

      final user = response.user;
      if (user == null) {
        return const Left('errorCreateAccountFailed');
      }

      // [APP-C-04 FIXED] The DB trigger `trg_auth_user_created` runs synchronously
      // and inserts the user row (id, email, role) before signUp() returns.
      // We must NOT upsert unconditionally — that risks overwriting trigger values
      // with a concurrent write. Instead: UPDATE the trigger-created row with the
      // app-specific fields (name, phone, language, etc.).
      // If the UPDATE matches 0 rows (extremely rare edge case), fall back to upsert.
      Map<String, dynamic> userData;
      try {
        final updated = await SupabaseService.client
            .from('users')
            .update({
              'name': name,
              'phone': phone,
              'language': 'ar',
              'rating': 0.00,
              'total_trips': 0,
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id)
            .select(
                'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
            .maybeSingle()
            .timeout(const Duration(seconds: 15));

        if (updated != null) {
          userData = updated;
        } else {
          // Trigger row not yet visible (extremely rare) — fall back to upsert
          AppLogger.warning(
              'AuthRepositoryImpl: trigger row missing after signUp — falling back to upsert');
          userData = await SupabaseService.client
              .from('users')
              .upsert({
                'id': user.id,
                'name': name,
                'phone': phone,
                'email': email,
                'role': 'user',
                'rating': 0.00,
                'total_trips': 0,
                'language': 'ar',
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select(
                  'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
              .single()
              .timeout(const Duration(seconds: 15));
        }
      } catch (e) {
        try {
          // Final fallback: row may have been fully created by trigger
          userData = await SupabaseService.client
              .from('users')
              .select(
                  'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
              .eq('id', user.id)
              .single()
              .timeout(const Duration(seconds: 15));
          AppLogger.debug(
              'AuthRepositoryImpl: User already exists, fetched existing data');
        } catch (innerE) {
          AppLogger.debug('AuthRepositoryImpl: Fallback fetch failed: $innerE');
          return const Left('errorCreateAccountFailed');
        }
      }

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, UserEntity>> signUpDriver({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String nationalId,
    required String nationalIdImageUrl,
    required String licenseNumber,
    required String licenseImageUrl,
    required String criminalRecordUrl,
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String vehiclePlate,
    required String vehicleImageUrl,
  }) async {
    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'role': 'driver',
        },
      );

      final user = response.user;
      if (user == null) {
        return const Left('errorCreateAccountFailed');
      }

      final rpcResponse =
          await SupabaseService.client.rpc('create_driver_account', params: {
        'p_user_id': user.id,
        'p_name': name,
        'p_email': email,
        'p_phone': phone,
        'p_national_id': nationalId,
        'p_license_number': licenseNumber,
        'p_vehicle_type': vehicleType,
        'p_vehicle_brand': vehicleBrand,
        'p_vehicle_model': vehicleModel,
        'p_vehicle_year': vehicleYear,
        'p_vehicle_color': vehicleColor,
        'p_vehicle_plate': vehiclePlate,
        'p_national_id_image': nationalIdImageUrl,
        'p_license_image': licenseImageUrl,
        'p_criminal_record_image': criminalRecordUrl,
        'p_vehicle_image': vehicleImageUrl,
      });

      if (rpcResponse['success'] != true) {
        // [AUTH-07 FIX] Cleanup orphaned auth account to prevent user lockout
        try {
          await SupabaseService.client.auth.signOut();
        } catch (_) {}
        return Left(rpcResponse['error'] ?? 'errorCreateAccountFailed');
      }

      final userData = await SupabaseService.client
          .from('users')
          .select(
              'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
          .eq('id', user.id)
          .single();

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, void>> signOut() async {
    try {
      await SupabaseService.client.auth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, UserEntity?>> getCurrentUser() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        return const Right(null);
      }

      final userData = await SupabaseService.client
          .from('users')
          .select(
              'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
          .eq('id', user.id)
          .single();

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('network') ||
          msg.contains('timeout') ||
          msg.contains('socket')) {
        return const Left('errorNoInternet');
      }
      if (e.code == 'PGRST116') {
        final user = SupabaseService.currentUser;
        if (user != null) {
          final meta = user.userMetadata ?? {};
          if (meta['role'] == 'user') {
            final userData = await SupabaseService.client
                .from('users')
                .upsert({
                  'id': user.id,
                  'name': meta['name'] ?? 'User',
                  'phone': meta['phone'] ?? '',
                  'email': user.email ?? '',
                  'role': 'user',
                  'rating': 0.00,
                  'total_trips': 0,
                  'language': 'ar',
                  'is_active': true,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .select()
                .single();
            return Right(UserModel.fromJson(userData).toEntity());
          }
        }
        await SupabaseService.client.auth.signOut();
        return const Right(null);
      }
      return Left(_mapError(e));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, UserEntity>> updateProfile({
    required String userId,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final userData = await SupabaseService.client
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select(
              'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
          .single();

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, String>> uploadDocument({
    required File file,
    required String path,
  }) async {
    try {
      final url = await _r2StorageService.uploadFile(file: file, path: path);
      return Right(url);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<String, bool>> getDriverIsVerified(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('drivers_profile')
          .select('is_verified')
          .eq('id', userId)
          .single();
      return Right(data['is_verified'] as bool? ?? false);
    } catch (e) {
      return const Right(false);
    }
  }
}
