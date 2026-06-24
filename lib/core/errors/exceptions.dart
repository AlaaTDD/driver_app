/// ══════════════════════════════════════════════════════════════
/// exceptions.dart — نظام الاستثناءات الموحَّد
///
/// التسلسل:
///   AppException (abstract base)
///     ├── NetworkException    — لا اتصال / timeout
///     ├── AuthException       — غير مسموح / جلسة منتهية
///     ├── ValidationException — خطأ في المدخلات
///     ├── ServerException     — خطأ في السيرفر أو قاعدة البيانات
///     ├── NotFoundException   — مورد غير موجود
///     ├── PermissionException — صلاحيات مرفوضة (location, camera)
///     ├── StorageException    — خطأ في رفع / حذف الملفات
///     └── TimeoutException    — انتهاء المهلة
///
/// الاستخدام:
///   throw NetworkException();
///   throw ServerException('errorLoadTrips', code: 'TRIP_404');
///   on AppException catch (e) { AppToast.error(ErrorMapper.getErrorMessage(ctx, e.message)); }
/// ══════════════════════════════════════════════════════════════
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? details;
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() =>
      '${runtimeType}(code: $code, message: $message'
      '${details != null ? ", details: $details" : ""})';
}

/// ─── Network ─────────────────────────────────────────────────
/// يُرمى عند انعدام الاتصال أو انتهاء مهلة الطلب
class NetworkException extends AppException {
  const NetworkException([
    String message = 'errorNoInternet',
    String? code,
  ]) : super(message, code: code ?? 'network_error');
}

/// ─── Auth ────────────────────────────────────────────────────
/// يُرمى عند انتهاء الجلسة أو رفض الوصول
class AuthException extends AppException {
  const AuthException(String message, {String? code, Object? details})
      : super(message, code: code ?? 'auth_error', details: details);
}

/// ─── Validation ──────────────────────────────────────────────
/// يُرمى عند فشل التحقق من مدخلات المستخدم
class ValidationException extends AppException {
  const ValidationException(
    String message, {
    String? code,
    Object? details,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'validation_error',
          details: details,
          stackTrace: stackTrace,
        );
}

/// ─── Server ──────────────────────────────────────────────────
/// يُرمى عند استجابة خاطئة من السيرفر أو قاعدة البيانات
class ServerException extends AppException {
  const ServerException(
    String message, {
    String? code,
    Object? details,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'server_error',
          details: details,
          stackTrace: stackTrace,
        );
}

/// ─── Not Found ────────────────────────────────────────────────
/// يُرمى عند عدم وجود مورد مطلوب (رحلة، مستخدم، ملف)
class NotFoundException extends AppException {
  const NotFoundException(String message, {String? code})
      : super(message, code: code ?? 'not_found');
}

/// ─── Permission ──────────────────────────────────────────────
/// يُرمى عند رفض أذونات النظام (الموقع، الكاميرا، الإشعارات)
class PermissionException extends AppException {
  const PermissionException([
    String message = 'errorPermissionDenied',
    String? code,
  ]) : super(message, code: code ?? 'permission_denied');
}

/// ─── Storage ─────────────────────────────────────────────────
/// يُرمى عند فشل رفع أو تنزيل أو حذف ملف
class StorageException extends AppException {
  const StorageException(
    String message, {
    String? code,
    Object? details,
  }) : super(message, code: code ?? 'storage_error', details: details);
}

/// ─── Timeout ─────────────────────────────────────────────────
/// يُرمى عند انتهاء مهلة العملية
class TimeoutException extends AppException {
  const TimeoutException([
    String message = 'errorRequestTimeout',
    String? code,
  ]) : super(message, code: code ?? 'timeout');
}
