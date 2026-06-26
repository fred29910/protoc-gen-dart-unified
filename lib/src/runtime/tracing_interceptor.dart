import 'dart:math';
import 'rpc_interceptor.dart';
import 'rpc_call_options.dart';

/// Interceptor that injects W3C TraceContext `traceparent` header.
///
/// Format: `00-{traceId}-{parentId}-{traceFlags}`
///
/// References:
/// - https://www.w3.org/TR/trace-context/
class TracingInterceptor implements RpcInterceptor {
  final String Function()? _traceIdProvider;
  final String Function()? _parentIdProvider;

  /// Creates a tracing interceptor that generates random trace IDs.
  const TracingInterceptor()
    : _traceIdProvider = null,
      _parentIdProvider = null;

  /// Creates a tracing interceptor with custom trace/parent ID providers.
  const TracingInterceptor.withProviders({
    required String Function() traceIdProvider,
    required String Function() parentIdProvider,
  }) : _traceIdProvider = traceIdProvider,
       _parentIdProvider = parentIdProvider;

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    final traceparent = _buildTraceparent();
    final existingHeaders = context.options?.headers ?? {};
    final updatedHeaders = Map<String, String>.from(existingHeaders);
    updatedHeaders['traceparent'] = traceparent;
    final baseOptions = context.options ?? const RpcCallOptions();
    final updatedOptions = baseOptions.copyWith(headers: updatedHeaders);
    final updatedContext = context.copyWith(options: updatedOptions);
    return proceed(updatedContext);
  }

  String _buildTraceparent() {
    final traceId = _traceIdProvider != null
        ? _traceIdProvider()
        : _generateHex(32);
    final parentId = _parentIdProvider != null
        ? _parentIdProvider()
        : _generateHex(16);
    return '00-$traceId-$parentId-01';
  }

  static String _generateHex(int length) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
