import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/r2_storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/models/driver_profile_model.dart' show DriverAccountStatus;
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
  // [AUTH-25 FIX / Validation-refactor FIX] A native Dart TimeoutException
  // (thrown when our own .timeout(...) call fires) means the request took
  // too long to respond — distinct from having no internet connection at all.
  if (msg.contains('timeoutexception') || msg.contains('future not completed')) {
    return 'errorRequestTimeout';
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
  // [Validation-refactor FIX] Expired/invalid session or JWT — the user needs
  // to sign in again; distinct from a plain connectivity failure.
  if (msg.contains('jwt expired') ||
      msg.contains('invalid jwt') ||
      msg.contains('token expired') ||
      msg.contains('session expired') ||
      msg.contains('refresh_token_not_found') ||
      msg.contains('invalid refresh token')) {
    return 'errorSessionExpired';
  }
  // [Validation-refactor FIX] Row-Level Security / authorization failures.
  if (msg.contains('permission denied') ||
      msg.contains('not authorized') ||
      msg.contains('forbidden') ||
      msg.contains('42501') ||
      msg.contains('row-level security') ||
      msg.contains('row level security')) {
    return 'errorPermissionDenied';
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
  // [Validation-refactor FIX] Upstream (Supabase/Postgres) temporarily down —
  // distinct from a 500 caused specifically by our own DB trigger below.
  if (msg.contains('status: 503') || msg.contains('status=503') ||
      msg.contains('"status":503') || msg.contains('statuscode: 503') ||
      msg.contains('status: 502') || msg.contains('status=502') ||
      msg.contains('"status":502') || msg.contains('statuscode: 502') ||
      msg.contains('status: 504') || msg.contains('status=504') ||
      msg.contains('"status":504') || msg.contains('statuscode: 504') ||
      msg.contains('service unavailable') || msg.contains('bad gateway') ||
      msg.contains('gateway timeout')) {
    return 'errorServerUnavailable';
  }
  // [AUTH-500 FIX] Supabase returns status=500 when the on-auth-user-created
  // DB trigger fails (e.g. NOT NULL violation on users.phone or users.name).
  // Map this to a clear error so the user gets a meaningful message.
  if (msg.contains('status: 500') || msg.contains('status=500') ||
      msg.contains('"status":500') || msg.contains('statuscode: 500')) {
    return 'errorCreateAccountFailed';
  }
  // [Validation-refactor FIX] Malformed/invalid payload rejected by the DB.
  if (msg.contains('invalid input syntax') ||
      msg.contains('violates check constraint') ||
      msg.contains('invalid text representation') ||
      msg.contains('22p02') ||
      msg.contains('status: 400') || msg.contains('status=400') ||
      msg.contains('"status":400') || msg.contains('statuscode: 400')) {
    return 'errorInvalidDataSent';
  }
  // [Validation-refactor FIX] Generic uniqueness/state conflict not already
  // covered by the more specific email/phone checks above.
  if (msg.contains('duplicate key') ||
      msg.contains('unique constraint') ||
      msg.contains('23505') ||
      msg.contains('conflict') ||
      msg.contains('status: 409') || msg.contains('status=409') ||
      msg.contains('"status":409') || msg.contains('statuscode: 409')) {
    return 'errorDataConflict';
  }
  // [Validation-refactor FIX] Generic client/HTTP failure while sending the
  // request that wasn't already identified as a connectivity issue above.
  if (msg.contains('clientexception') || msg.contains('httpexception')) {
    return 'errorSendingData';
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
    required String vehicleCategory,
    required String vehicleBrand,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String vehiclePlate,
    required String vehicleImageUrl,
  }) async {
    // [ATOMIC-FIX] كانت العملية سابقًا خطوتين منفصلتين: auth.signUp() ثم
    // rpc('create_driver_account') منفصل. لو الخطوة الثانية فشلت، حساب
    // auth.users كان يفضل موجود فعليًا (auth.signOut() بيعمل logout بس،
    // مش حذف)، فالمستخدم يواجه "الإيميل/الرقم مستخدم" عند إعادة المحاولة
    // رغم إن التسجيل اعتُبر فاشلًا بالكامل.
    //
    // الحل: الخطوتين بقوا داخل Edge Function واحدة (create-driver-account)
    // شغالة بصلاحيات service_role على السيرفر، بتعمل rollback حقيقي
    // (auth.admin.deleteUser) لو فشلت أي خطوة بعد إنشاء حساب الـ auth —
    // فالعملية بقت ذرّية فعليًا من منظور المستخدم.
    try {
      final response = await SupabaseService.client.functions.invoke(
        'create-driver-account',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'national_id': nationalId,
          'license_number': licenseNumber,
          'vehicle_category': vehicleCategory,
          'vehicle_brand': vehicleBrand,
          'vehicle_model': vehicleModel,
          'vehicle_year': vehicleYear,
          'vehicle_color': vehicleColor,
          'vehicle_plate': vehiclePlate,
          'national_id_image_url': nationalIdImageUrl,
          'license_image_url': licenseImageUrl,
          'criminal_record_image_url': criminalRecordUrl,
          'vehicle_image_url': vehicleImageUrl,
        },
      ).timeout(const Duration(seconds: 30));

      final data = response.data;
      if (data is! Map || data['success'] != true) {
        final errorMsg =
            (data is Map ? data['error'] as String? : null) ??
                'errorCreateAccountFailed';
        return Left(errorMsg);
      }

      final userData = Map<String, dynamic>.from(data['user'] as Map);
      final userModel = UserModel.fromJson(userData);
      return Right(userModel.toEntity());
    } on FunctionException catch (e) {
      // [FUNCTION-EX FIX] supabase_flutter يرمي FunctionException كـ exception
      // (مش response عادي) لأي status code غير 2xx — يعني كل حالات الفشل
      // اللي الـ Edge Function نفسها بترجعها (400 لفشل RPC، 500 لفشل fetch)
      // كانت بتوصل هنا مباشرة بدل السطر فوق، وبتضيع رسالة الخطأ الحقيقية
      // لأن الكود القديم كان بيعامل كل الـ exceptions بنفس الطريقة العامة.
      // e.details بيحمل جسم الـ JSON اللي رجّعته الدالة نفسها ({success,error}).
      final details = e.details;
      String? serverError;
      if (details is Map) {
        serverError = details['error'] as String?;
      } else if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) serverError = decoded['error'] as String?;
        } catch (_) {
          // details مش JSON صالح — نتجاهله ونستخدم fallback تحت.
        }
      }
      AppLogger.error(
          'AuthRepositoryImpl: signUpDriver FunctionException status=${e.status} details=$details');
      return Left(serverError ?? 'errorCreateAccountFailed');
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

  // [البند 17 — المراجعة النهائية] حُذفت getDriverIsVerified() من هنا —
  // كانت تستعلم is_verified مباشرة (الفحص لمرة واحدة القديم)، ولم يعد لها
  // أي مستدعٍ في المشروع بعد اكتمال المرحلة ج (watchDriverAccountStatus
  // أدناه حلّت محلها فعلياً في AuthBloc). تأكيد الحذف: grep_search على
  // lib/ و test/ لم يُظهر أي استدعاء متبقٍّ، وdart analyze + flutter test
  // رجعا نظيفَين بعد الحذف. انظر MASTER_PLAN.md القسم 4، البند 17.

  @override
  Stream<({DriverAccountStatus status, String? revisionReason})>
      watchDriverAccountStatus(String driverId) {
    final controller =
        StreamController<({DriverAccountStatus status, String? revisionReason})>();

    Future<void> emitCurrent() async {
      try {
        final data = await SupabaseService.client
            .from('drivers_profile')
            .select('account_status, revision_reason')
            .eq('id', driverId)
            .single();
        controller.add((
          status: DriverAccountStatus.fromValue(data['account_status'] as String?),
          revisionReason: data['revision_reason'] as String?,
        ));
      } catch (e, st) {
        AppLogger.error('AuthRepositoryImpl: watchDriverAccountStatus initial fetch failed',
            tag: 'AuthRepositoryImpl', error: e, stackTrace: st);
      }
    }

    // قيمة أولية فوراً (قبل أول حدث Realtime)، بنفس نمط watchDriverProfileة.
    emitCurrent();

    final channel = SupabaseService.client
        .channel('driver_account_status_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers_profile',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: driverId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            controller.add((
              status: DriverAccountStatus.fromValue(newRow['account_status'] as String?),
              revisionReason: newRow['revision_reason'] as String?,
            ));
          },
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }
}
