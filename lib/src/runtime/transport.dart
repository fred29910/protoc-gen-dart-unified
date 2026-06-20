class RpcCallOptions {
  final Map<String, String>? headers;
  final Duration? timeout;

  const RpcCallOptions({this.headers, this.timeout});
}

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
}
