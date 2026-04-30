// lib/core/utils/retry_helper.dart
// FIX: Missing Feature #2 — Retry/Exponential Backoff on Network Failures

import 'dart:async';
import 'dart:math' as math;

/// Executes [operation] with exponential backoff retry.
///
/// - [maxAttempts]  total tries (default 3)
/// - [initialDelay] first wait duration (default 500ms)
/// - [maxDelay]     cap on wait duration (default 8s)
/// - [retryIf]      optional predicate; if returns false the error is thrown immediately
/// - [onRetry]      optional callback for logging / analytics
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  Duration maxDelay = const Duration(seconds: 8),
  bool Function(Exception error)? retryIf,
  void Function(Exception error, int attempt)? onRetry,
}) async {
  var attempt = 1;
  while (true) {
    try {
      return await operation();
    } on Exception catch (e) {
      if (attempt >= maxAttempts || (retryIf != null && !retryIf(e))) {
        rethrow;
      }
      onRetry?.call(e, attempt);
      final delay = Duration(
        milliseconds: math.min(
          maxDelay.inMilliseconds,
          initialDelay.inMilliseconds * math.pow(2, attempt - 1).toInt(),
        ),
      );
      await Future.delayed(delay);
      attempt++;
    }
  }
}
