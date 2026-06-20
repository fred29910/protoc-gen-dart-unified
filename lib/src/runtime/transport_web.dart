import 'package:dio/dio.dart';
import 'transport.dart';
import 'api_exception.dart';

/// Creates a transport for web platforms.
///
/// Web only supports HTTP transport (no gRPC).
Transport? createTransport(String endpoint) {
  return HttpTransport(endpoint);
}

/// HTTP transport implementation for web using dio.
class HttpTransport implements Transport {
  final Dio _dio;

  HttpTransport(String endpoint) : _dio = Dio(BaseOptions(baseUrl: endpoint));

  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        '/$serviceName/$methodName',
        data: request,
        options: Options(
          method: 'POST',
          headers: options?.headers,
          sendTimeout: options?.timeout,
          receiveTimeout: options?.timeout,
        ),
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    throw UnimplementedError(
        'HTTP server streaming requires SSE, deferred to Phase 3');
  }

  ApiException _mapDioException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final grpcCode = _httpStatusToGrpcCode(status);
    final message = e.message ?? 'HTTP error';
    return _createApiException(grpcCode, message);
  }

  int _httpStatusToGrpcCode(int status) {
    return switch (status) {
      400 => 3,
      401 => 16,
      403 => 7,
      404 => 5,
      409 => 6,
      429 => 8,
      422 => 3,
      500 => 13,
      501 => 12,
      502 => 14,
      503 => 14,
      504 => 4,
      _ => 2,
    };
  }

  ApiException _createApiException(int code, String message) {
    return switch (code) {
      1 => CancelledException(message),
      2 => UnknownException(message),
      3 => InvalidArgumentException(message),
      4 => RpcTimeoutException(message),
      5 => NotFoundException(message),
      6 => AlreadyExistsException(message),
      7 => PermissionDeniedException(message),
      8 => ResourceExhaustedException(message),
      9 => FailedPreconditionException(message),
      10 => AbortedException(message),
      11 => OutOfRangeException(message),
      12 => UnimplementedException(message),
      13 => InternalServerException(message),
      14 => UnavailableException(message),
      15 => DataLossException(message),
      16 => UnauthenticatedException(message),
      _ => InternalServerException(message),
    };
  }
}
