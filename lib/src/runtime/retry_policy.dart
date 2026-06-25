import 'dart:math';

/// Configuration for automatic retry with exponential backoff + jitter.
class RetryPolicy {
  /// Maximum number of retry attempts (not counting the initial attempt).
  final int maxAttempts;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Jitter factor (0.0 = no jitter, 1.0 = full jitter).
  final double jitterFactor;

  /// Predicate to determine if an exception should trigger a retry.
  final bool Function(Object error)? retryIf;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.25,
    this.retryIf,
  });

  /// Default retry policy: retries on unavailable / resource exhausted / deadline exceeded.
  static const RetryPolicy defaultPolicy = RetryPolicy();

  /// Whether the given error should be retried.
  bool shouldRetry(Object error) {
    if (retryIf != null) return retryIf!(error);
    return _defaultRetryIf(error);
  }

  static bool _defaultRetryIf(Object error) {
    // Retry on: UNAVAILABLE (14), RESOURCE_EXHAUSTED (8), DEADLINE_EXCEEDED (4)
    // Also retry on network-level errors (no specific code).
    final code = _extractCode(error);
    if (code == null) return true; // network errors → retry
    return code == 14 || code == 8 || code == 4;
  }

  static int? _extractCode(Object error) {
    // Use reflection-free approach: check for a `code` getter via dynamic.
    try {
      final dynamic d = error;
      final c = d.code;
      if (c is int) return c;
    } catch (_) {}
    return null;
  }

  /// Computes the delay before the given retry attempt (0-indexed).
  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;
    var delay =
        initialDelay.inMicroseconds *
        pow(backoffMultiplier, attempt - 1).toDouble();
    if (delay > maxDelay.inMicroseconds) {
      delay = maxDelay.inMicroseconds.toDouble();
    }
    // Apply jitter
    if (jitterFactor > 0) {
      final jitter = delay * jitterFactor * (Random().nextDouble() * 2 - 1);
      delay = (delay + jitter).clamp(0, maxDelay.inMicroseconds.toDouble());
    }
    return Duration(microseconds: delay.round());
  }
}
