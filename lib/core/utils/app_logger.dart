import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';


class AppLogger {
  AppLogger._();

  /// اضبطه على true لتفعيل اللوج في builds الـ QA
  static bool enableInRelease = false;

  static bool _crashlyticsReady = false;

  /// استدعِه مرة واحدة من main() بعد Firebase.initializeApp()
  static void initCrashlytics() {
    if (_crashlyticsReady) return;
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _crashlyticsReady = true;
    } catch (_) {
      // Crashlytics غير متاحة (Web / Windows) — تراجع آمن
    }
  }

  // ─── Error ───────────────────────────────────────────────────
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    _log('❌', tag, message, error: error, stackTrace: stackTrace);
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: tag != null ? '[$tag] $message' : message,
        fatal: fatal,
      );
    }
  }

  // ─── Warning ─────────────────────────────────────────────────
  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    _log('⚠️', tag, message, error: error, stackTrace: stackTrace);
    if (kReleaseMode && _crashlyticsReady && fatal) {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: tag != null ? '[$tag] $message' : message,
        fatal: true,
      );
    }
  }

  // ─── Info ─────────────────────────────────────────────────────
  static void info(String message, {String? tag}) =>
      _log('ℹ️', tag, message);

  // ─── Debug ────────────────────────────────────────────────────
  /// محجوب دائماً في release — بدون قيد enableInRelease
  static void debug(String message, {String? tag}) {
    if (kReleaseMode) return;
    _log('🔍', tag, message);
  }

  // ─── Performance timer ───────────────────────────────────────
  /// يبدأ مؤقتاً ويعيد دالة إيقاف تطبع الوقت المنقضي.
  ///
  /// ```dart
  /// final stop = AppLogger.startTimer('fetchTrips', tag: 'Repo');
  /// await repo.fetchTrips();
  /// stop(); // ⚡ [Repo] fetchTrips → 124 ms
  /// ```
  static VoidCallback startTimer(String label, {String? tag}) {
    final sw = Stopwatch()..start();
    return () {
      sw.stop();
      _log('⚡', tag, '$label → ${sw.elapsedMilliseconds} ms');
    };
  }

  // ─── Internal ────────────────────────────────────────────────
  static void _log(
    String emoji,
    String? tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode && !enableInRelease) return;
    final prefix = tag != null ? '$emoji [$tag] ' : '$emoji ';
    debugPrint('$prefix$message');
    if (error != null) debugPrint('  ↳ Error: $error');
    if (stackTrace != null) debugPrint('  ↳ Stack: $stackTrace');
  }
}
