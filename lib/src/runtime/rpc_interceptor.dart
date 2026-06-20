abstract class RpcInterceptor {
  Future<T> intercept<T>(
    String serviceName,
    String methodName,
    Object request,
    Future<T> Function() proceed,
  );
}
