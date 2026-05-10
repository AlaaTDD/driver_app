
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/r2_storage_service.dart';
import '../../../../services/supabase_service.dart';
import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';


String _mapError(dynamic e) {
  debugPrint('🔴 AUTH ERROR [${e.runtimeType}]: $e');
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
    return 'errorInvalidCredentials';
  }
  if (msg.contains('user already registered') || msg.contains('already been registered')) {
    return 'errorEmailRegistered';
  }
  if (msg.contains('email not confirmed')) {
    return 'errorConfirmEmail';
  }
  if (msg.contains('password should be at least')) {
    return 'errorPasswordLength';
  }
  if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
    return 'errorNoInternet';
  }
  if (msg.contains('too many requests') || msg.contains('rate limit')) {
    return 'errorRateLimit';
  }
  if (msg.contains('row not found') || msg.contains('pgrst116')) {
    return 'errorUserNotFound';
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
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return const Left('errorLoginFailed');
      }

      Map<String, dynamic>? userData;
      try {
        userData = await SupabaseService.client
            .from('users')
            .select('id,name,phone,email,avatar_url,role,rating,total_trips,language,fcm_token,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
            .eq('id', user.id)
            .single();
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST116') {
          // Auto-recovery: Create missing profile using auth metadata
          final meta = user.userMetadata ?? {};
          if (meta['role'] == 'driver') {
            await SupabaseService.client.auth.signOut();
            return const Left('errorDriverProfileIncomplete');
          }
          userData = await SupabaseService.client.from('users').upsert({
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
          }).select().single();
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
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'role': 'user',
        },
      );

      final user = response.user;
      if (user == null) {
        return const Left('errorCreateAccountFailed');
      }

      
      
      Map<String, dynamic> userData;
      try {
        userData = await SupabaseService.client.from('users').upsert({
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
        }).select().single();
      } catch (e) {
        try {
          // Fallback if upsert still fails
          userData = await SupabaseService.client
              .from('users')
              .select('id,name,phone,email,avatar_url,role,rating,total_trips,language,fcm_token,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
              .eq('id', user.id)
              .single();
          debugPrint('AuthRepositoryImpl: User already exists, fetched existing data');
        } catch (innerE) {
          debugPrint('AuthRepositoryImpl: Fallback fetch failed: $innerE');
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

      final rpcResponse = await SupabaseService.client.rpc('create_driver_account', params: {
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
        return Left(rpcResponse['error'] ?? 'errorCreateAccountFailed');
      }

      final userData = await SupabaseService.client
          .from('users')
          .select('id,name,phone,email,avatar_url,role,rating,total_trips,language,fcm_token,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
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
          .select('id,name,phone,email,avatar_url,role,rating,total_trips,language,fcm_token,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
          .eq('id', user.id)
          .single();

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('network') || msg.contains('timeout') || msg.contains('socket')) {
        return const Left('errorNoInternet');
      }
      if (e.code == 'PGRST116') {
        final user = SupabaseService.currentUser;
        if (user != null) {
           final meta = user.userMetadata ?? {};
           if (meta['role'] == 'user') {
              final userData = await SupabaseService.client.from('users').upsert({
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
              }).select().single();
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
          .select('id,name,phone,email,avatar_url,role,rating,total_trips,language,fcm_token,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at')
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
