// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/r2_storage_service.dart';
import '../../../../services/supabase_service.dart';
import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

/// Converts Supabase/network exceptions to readable Arabic messages.
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

      final userData = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

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
      );

      final user = response.user;
      if (user == null) {
        return const Left('errorCreateAccountFailed');
      }

      // FIX P2-06: Use insert instead of upsert to avoid overwriting existing data
      // on re-registration. If user already exists, catch the conflict and fetch existing.
      Map<String, dynamic> userData;
      try {
        userData = await SupabaseService.client.from('users').insert({
          'id': user.id,
          'name': name,
          'phone': phone,
          'email': email,
          'role': 'user',
          'rating': 5.00,
          'total_trips': 0,
          'language': 'ar',
          'is_active': true,
          'is_admin': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();
      } catch (e) {
        // User already exists in DB — fetch existing record without overwriting
        userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();
        debugPrint('AuthRepositoryImpl: User already exists, fetched existing data');
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
          .select()
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
          .select()
          .eq('id', user.id)
          .single();

      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } on PostgrestException catch (e) {
      // FIX P2-07: Distinguish network errors from "no user" case.
      // Don't silently log out users on weak network.
      final msg = e.message.toLowerCase();
      if (msg.contains('network') || msg.contains('timeout') || msg.contains('socket')) {
        return const Left('errorNoInternet');
      }
      if (e.code == 'PGRST116') {
        // Row not found — user deleted from DB but still in auth
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
          .select()
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
