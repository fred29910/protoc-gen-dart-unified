import 'dart:async';
import 'rpc_interceptor.dart';
import 'retry_policy.dart';
import 'api_exception.dart';

/// Interceptor that retries failed calls according to a [RetryPolicy].
class RetryInterceptor implements RpcInterceptor {
  final RetryPolicy _policy;

  const RetryInterceptor([this._policy = RetryPolicy.defaultPolicy]);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _policy.maxAttempts; attempt++) {
      try {
        return await proceed(context);
      } on ApiException catch (e) {
        lastError = e;
        if (attempt >= _policy.maxAttempts || !_policy.shouldRetry(e)) {
          rethrow;
        }
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt >= _policy.maxAttempts) rethrow;
      }
      final delay = _policy.delayForAttempt(attempt + 1);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
    // Should not reach here, but just in case
    throw lastError ?? InternalServerException('Retry exhausted');
  }
}
