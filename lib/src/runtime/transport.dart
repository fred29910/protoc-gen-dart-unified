import 'rpc_call_options.dart';
import 'rpc_interceptor.dart';

export 'rpc_call_options.dart';
export 'rpc_cancel_token.dart';
export 'rpc_interceptor.dart';

abstract class Transport {
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });

  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });

  /// Executes a function through the interceptor chain.
  ///
  /// Interceptors are executed in order. Each interceptor receives a
  /// [proceed] callback that invokes the next interceptor in the chain,
  /// ultimately calling [finalCall].
  Future<T> executeWithInterceptors<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
    List<RpcInterceptor> interceptors,
    Future<T> Function(Object req, RpcCallOptions? opts) finalCall,
  ) {
    Future<T> next(int index, InterceptorContext ctx) {
      if (index >= interceptors.length) {
        return finalCall(ctx.request, ctx.options);
      }
      return interceptors[index].intercept(
        ctx,
        (nextCtx) => next(index + 1, nextCtx),
      );
    }

    return next(
      0,
      InterceptorContext(
        serviceName: serviceName,
        methodName: methodName,
        request: request,
        options: options,
      ),
    );
  }
}
