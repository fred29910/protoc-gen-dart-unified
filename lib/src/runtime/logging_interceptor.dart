import 'rpc_interceptor.dart';

/// Log function signature for the logging interceptor.
typedef RpcLogger = void Function(String message);

/// Interceptor that logs RPC calls (start, success, failure).
///
/// This is an optional interceptor — the core runtime does not depend on
/// any specific logging library. Users provide their own [logger] function.
class LoggingInterceptor implements RpcInterceptor {
  final RpcLogger _logger;

  const LoggingInterceptor(this._logger);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    final serviceName = context.serviceName;
    final methodName = context.methodName;
    _logger('→ $serviceName/$methodName');
    try {
      final result = await proceed(context);
      _logger('← $serviceName/$methodName OK');
      return result;
    } catch (e) {
      _logger('← $serviceName/$methodName ERROR: $e');
      rethrow;
    }
  }
}
