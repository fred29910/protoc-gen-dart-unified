import 'dart:async';
import 'retry_policy.dart';

/// Executes a function with automatic retry according to [policy].
///
/// If [shouldRetry] is provided, it will be called to determine whether
/// an error should trigger a retry. If not provided, the default
/// [RetryPolicy.shouldRetry] logic is used.
///
/// ```dart
/// final result = await withRetry(
///   () => api.getUser(request),
///   RetryPolicy(maxAttempts: 3, initialDelay: Duration(milliseconds: 100)),
/// );
/// ```
Future<T> withRetry<T>(
  Future<T> Function() fn,
  RetryPolicy policy, {
  bool Function(Object error)? shouldRetry,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt <= policy.maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      lastError = e;
      if (attempt >= policy.maxAttempts) rethrow;
      final retryPredicate = shouldRetry ?? policy.shouldRetry;
      if (!retryPredicate(e)) rethrow;
      final delay = policy.delayForAttempt(attempt + 1);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
  }
  // Should not reach here, but just in case
  throw lastError ?? Exception('Retry exhausted');
}
