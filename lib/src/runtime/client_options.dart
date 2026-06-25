import 'protocol.dart';
import 'rpc_interceptor.dart';
import 'retry_interceptor.dart';
import 'retry_policy.dart';
import 'tracing_interceptor.dart';

class ClientOptions {
  final String endpoint;
  final Protocol protocol;
  final Duration? timeout;

  /// Custom interceptors to execute around each RPC call.
  /// Executed in order: tracing -> user interceptors -> retry.
  final List<RpcInterceptor> interceptors;

  /// Default retry policy for all calls made through this client.
  /// Set to null to disable automatic retry.
  /// A [RetryInterceptor] is automatically appended to the interceptor chain
  /// when this is non-null and [autoRetryEnabled] is true.
  final RetryPolicy? retryPolicy;

  /// Whether to enable W3C traceparent injection.
  /// When true, a [TracingInterceptor] is prepended to the interceptor chain.
  final bool tracingEnabled;

  /// Whether to automatically mount [RetryInterceptor] when [retryPolicy] is set.
  final bool autoRetryEnabled;

  const ClientOptions({
    required this.endpoint,
    this.protocol = Protocol.auto,
    this.timeout,
    this.interceptors = const [],
    this.retryPolicy,
    this.tracingEnabled = true,
    this.autoRetryEnabled = true,
  });

  /// Builds the effective interceptor chain for this client.
  /// Order: tracing (if enabled) -> user interceptors -> retry (if enabled).
  List<RpcInterceptor> buildInterceptorChain() {
    final chain = <RpcInterceptor>[];
    if (tracingEnabled) {
      chain.add(const TracingInterceptor());
    }
    chain.addAll(interceptors);
    if (autoRetryEnabled && retryPolicy != null) {
      chain.add(RetryInterceptor(retryPolicy!));
    }
    return chain;
  }
}
