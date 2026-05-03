


import 'dart:async';
import 'dart:math' as math;








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
