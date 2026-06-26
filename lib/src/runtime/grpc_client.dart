import 'rpc_call_options.dart';

/// Abstract interface for the gRPC client that wraps generated
/// *ServiceClient classes from protoc_plugin (pbgrpc.dart).
///
/// Provides typed [unaryCall] and [serverStream] methods that delegate
/// to the appropriate method on the underlying *ServiceClient.
abstract class GrpcClient {
  /// Performs a unary gRPC call.
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });

  /// Performs a server-streaming gRPC call.
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });
}
