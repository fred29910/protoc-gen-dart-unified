class RpcCallOptions {
  final Map<String, String>? headers;
  final Duration? timeout;
  final String? httpPath;
  final String? httpMethod;
  final Map<String, dynamic>? httpQueryParams;
  final dynamic httpBody;

  const RpcCallOptions({
    this.headers,
    this.timeout,
    this.httpPath,
    this.httpMethod,
    this.httpQueryParams,
    this.httpBody,
  });
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
