import 'dart:async';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'transport.dart';
import 'api_exception.dart';
import 'sse_parser.dart';

/// Creates a transport for native platforms (iOS, Android, Desktop).
///
/// Returns an HttpTransport for HTTP-only mode, or null if gRPC is needed
/// but no gRPC client is available.
Transport? createTransport(String endpoint, {dynamic grpcClient}) {
  // Native platform: always return HttpTransport for HTTP.
  // For gRPC, the generated code uses grpcClient directly via _grpcClient field.
  return HttpTransport(endpoint);
}

/// HTTP transport implementation using dio.
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
      final method = options?.httpMethod ?? 'POST';
      final path = options?.httpPath ?? '/$serviceName/$methodName';
      final data = options?.httpBody;
      final queryParameters = options?.httpQueryParams;

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
    // Phase 3: SSE streaming via dart:io HttpClient
    // Note: For Web platforms, use transport_web.dart which may need
    // package:http with fetch_client for SSE support.
    return _sseStream<T>(serviceName, methodName, request, options);
  }

  Stream<T> _sseStream<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
  ) {
    final controller = StreamController<T>();
    final path = options?.httpPath ?? '/$serviceName/$methodName';
    final uri = Uri.parse('${_dio.options.baseUrl}$path');

    // Build query parameters
    final queryParams = <String, dynamic>{};
    if (options?.httpQueryParams != null) {
      queryParams.addAll(options!.httpQueryParams!);
    }
    final fullUri = uri.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    io.HttpClient().openUrl(options?.httpMethod ?? 'GET', fullUri).then((req) {
      // Add headers
      options?.headers?.forEach((key, value) {
        req.headers.set(key, value);
      });
      req.headers.set('Accept', 'text/event-stream');
      req.headers.set('Cache-Control', 'no-cache');

      // Add body for non-GET methods
      if (options?.httpBody != null &&
          (options?.httpMethod ?? 'GET') != 'GET') {
        final bodyData = options!.httpBody;
        if (bodyData is String) {
          req.write(bodyData);
        } else {
          req.write(bodyData.toString());
        }
      }

      return req.close().then((response) {
        if (response.statusCode != 200) {
          controller.addError(InternalServerException(
              'SSE connection failed with status ${response.statusCode}'));
          controller.close();
          return;
        }
        SseParser.parse(response).listen(
          (data) {
            // Each SSE data line is a JSON-encoded message
            // The generated code handles deserialization
            controller.add(data as T);
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      });
    }).catchError((Object e, StackTrace st) {
      controller.addError(e, st);
    });

    return controller.stream;
  }

  ApiException _mapDioException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    // Map HTTP status to gRPC code, then to ApiException
    final grpcCode = _httpStatusToGrpcCode(status);
    final message = e.message ?? 'HTTP error';
    return _createApiException(grpcCode, message);
  }

  int _httpStatusToGrpcCode(int status) {
    // Reverse mapping: HTTP status → gRPC canonical code
    return switch (status) {
      400 => 3,  // INVALID_ARGUMENT
      401 => 16, // UNAUTHENTICATED
      403 => 7,  // PERMISSION_DENIED
      404 => 5,  // NOT_FOUND
      409 => 6,  // ALREADY_EXISTS
      429 => 8,  // RESOURCE_EXHAUSTED
      422 => 3,  // INVALID_ARGUMENT (unprocessable entity)
      500 => 13, // INTERNAL
      501 => 12, // UNIMPLEMENTED
      502 => 14, // UNAVAILABLE
      503 => 14, // UNAVAILABLE
      504 => 4,  // DEADLINE_EXCEEDED
      _ => 2,    // UNKNOWN
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

/// gRPC transport implementation that delegates to generated *ServiceClient.
///
/// This is a scaffold — full implementation requires the generated
/// *ServiceClient classes from protoc-gen-dart.
class GrpcTransport implements Transport {
  final dynamic _client;

  GrpcTransport(this._client);

  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    // gRPC unary call delegates to the generated *ServiceClient.
    // The generated code casts _client to the correct type and calls the method.
    throw UnimplementedError(
        'gRPC unary call requires generated *ServiceClient for '
        '$serviceName.$methodName. '
        'Pass the *ServiceClient from *.pbgrpc.dart to ApiSdk(grpcClient: ...).');
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    // gRPC server streaming delegates to the generated *ServiceClient.
    // The generated code casts _client to the correct type and calls the method.
    throw UnimplementedError(
        'gRPC server streaming requires generated *ServiceClient for '
        '$serviceName.$methodName. '
        'Pass the *ServiceClient from *.pbgrpc.dart to ApiSdk(grpcClient: ...).');
  }
}
