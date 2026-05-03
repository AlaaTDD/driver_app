
import 'dart:io';
import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<String, UserEntity>> signIn({
    required String email,
    required String password,
  });

  Future<Either<String, UserEntity>> signUpUser({
    required String name,
    required String phone,
    required String email,
    required String password,
  });

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
  });

  Future<Either<String, void>> signOut();

  Future<Either<String, UserEntity?>> getCurrentUser();

  Future<Either<String, UserEntity>> updateProfile({
    required String userId,
    String? name,
    String? avatarUrl,
  });

  Future<Either<String, String>> uploadDocument({
    required File file,
    required String path,
  });

  Future<Either<String, bool>> getDriverIsVerified(String userId);
}
