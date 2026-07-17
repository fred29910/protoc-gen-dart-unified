import 'package:dio/dio.dart';
import 'transport.dart';
import 'grpc_client.dart';
import 'api_exception.dart';

/// Creates a transport for web platforms.
///
/// Web only supports HTTP transport (no gRPC).
Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
}) {
  return HttpTransport(endpoint, interceptors: interceptors);
}

/// HTTP transport implementation for web using dio.
class HttpTransport extends Transport {
  final Dio _dio;
  final List<RpcInterceptor> _interceptors;

  HttpTransport(String endpoint, {List<RpcInterceptor> interceptors = const []})
    : _dio = Dio(BaseOptions(baseUrl: endpoint)),
      _interceptors = interceptors;

  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    return executeWithInterceptors<T>(
      serviceName,
      methodName,
      request,
      options,
      _interceptors,
      (req, opts) => _rawUnaryCall<T>(serviceName, methodName, req, opts),
    );
  }

  /// Core HTTP call without interceptor chain (used as finalCall).
  Future<T> _rawUnaryCall<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
  ) async {
    try {
      final method = options?.httpMethod ?? 'POST';
      final path = options?.httpPath ?? '/$serviceName/$methodName';
      final data = options?.httpBody;
      final queryParameters = options?.httpQueryParams;

      // Set up Dio CancelToken if RpcCancelToken is provided
      CancelToken? dioCancelToken;
      if (options?.cancelToken != null) {
        dioCancelToken = CancelToken();
        options!.cancelToken!.onCancel(() {
          if (!dioCancelToken!.isCancelled) {
            dioCancelToken.cancel('Cancelled by RpcCancelToken');
          }
        });
      }

      try {
        final response = await _dio.request<dynamic>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: Options(
            method: method.toUpperCase(),
            headers: options?.headers,
            sendTimeout: options?.timeout,
            receiveTimeout: options?.timeout,
          ),
          cancelToken: dioCancelToken,
        );
        return response.data as T;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel &&
            options?.cancelToken?.isCancelled == true) {
          throw CancelledException(
            options?.cancelToken?.cancelledReason?.toString() ??
                'Cancelled by RpcCancelToken',
          );
        }
        throw _mapDioException(e);
      }
    } finally {
      // Dio CancelToken is local; no cleanup needed
    }
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    // Phase 3: SSE streaming
    throw UnimplementedError(
      'HTTP server streaming requires SSE, deferred to Phase 3',
    );
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
