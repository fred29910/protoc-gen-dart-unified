import 'rpc_call_options.dart';

/// Context passed to each interceptor in the chain.
class InterceptorContext {
  final String serviceName;
  final String methodName;
  final Object request;
  final RpcCallOptions? options;

  const InterceptorContext({
    required this.serviceName,
    required this.methodName,
    required this.request,
    this.options,
  });

  InterceptorContext copyWith({
    String? serviceName,
    String? methodName,
    Object? request,
    RpcCallOptions? options,
  }) {
    return InterceptorContext(
      serviceName: serviceName ?? this.serviceName,
      methodName: methodName ?? this.methodName,
      request: request ?? this.request,
      options: options ?? this.options,
    );
  }
}

abstract class RpcInterceptor {
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  );
}
