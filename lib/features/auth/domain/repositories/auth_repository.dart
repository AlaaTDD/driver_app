import 'dart:io';
import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../../../core/models/driver_profile_model.dart' show DriverAccountStatus;

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
    required String vehicleCategory,
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

  /// اشتراك Realtime دائم على account_status/revision_reason لسائق معين،
  /// يبقى فعّالاً طوال الجلسة وليس فقط عند CheckAuthStatus/SignInRequested.
  /// [البند 17 — المراجعة النهائية] حلّت محل getDriverIsVerified (الفحص
  /// لمرة واحدة على is_verified) التي حُذفت لعدم وجود أي مستدعٍ لها في
  /// المشروع بعد اكتمال المرحلة ج — إبقاؤها كانت ستُبقي مصدر حقيقة موازياً
  /// ميتاً، بالضبط ما حذّر منه القسم 2.3 من MASTER_PLAN.md.
  /// انظر MASTER_PLAN.md القسم 4، المرحلة ج، البند 10.
  Stream<({DriverAccountStatus status, String? revisionReason})> watchDriverAccountStatus(
    String driverId,
  );
}
