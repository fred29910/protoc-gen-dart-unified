/// Generates a self-contained `unified_runtime.dart` file containing all
/// runtime types for the unified RPC SDK.
///
/// This template-based generator copies class definitions verbatim from
/// `lib/src/runtime/` sources, with only `package:dio/dio.dart` as an
/// external dependency. gRPC-only types and http_status_mapping are excluded
/// (dead / gRPC-only code).
import '../model/service_model.dart';

class RuntimeInlineGenerator {
  /// Returns the complete source code for `unified_runtime.dart`.
  String generate() {
    return '''
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
// DO NOT EDIT: Runtime support types for the unified RPC SDK.

import 'dart:async';
import 'dart:convert';
import 'dart:math' show pow, Random;
import 'package:dio/dio.dart';

// Re-export the platform transport factory so service/mock/example files that
// import this runtime can resolve `createTransport(...)` without knowing about
// the conditional-import split (approach A1: web/gRPC isolation).
export 'unified_transport_factory.dart';

// ============================================================
// Exception Hierarchy
// ============================================================

abstract class ApiException implements Exception {
  final String message;
  final int? code;

  const ApiException(this.message, [this.code]);

  @override
  String toString() => 'ApiException(\$code): \$message';
}

class InvalidArgumentException extends ApiException {
  const InvalidArgumentException([String? msg])
    : super(msg ?? 'Invalid argument', 3);
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([String? msg])
    : super(msg ?? 'Unauthenticated', 16);
}

class PermissionDeniedException extends ApiException {
  const PermissionDeniedException([String? msg])
    : super(msg ?? 'Permission denied', 7);
}

class NotFoundException extends ApiException {
  const NotFoundException([String? msg]) : super(msg ?? 'Not found', 5);
}

class ResourceExhaustedException extends ApiException {
  const ResourceExhaustedException([String? msg])
    : super(msg ?? 'Resource exhausted', 8);
}

class InternalServerException extends ApiException {
  const InternalServerException([String? msg])
    : super(msg ?? 'Internal server error', 13);
}

class RpcTimeoutException extends ApiException {
  const RpcTimeoutException([String? msg])
    : super(msg ?? 'Deadline exceeded', 4);
}

class CancelledException extends ApiException {
  const CancelledException([String? msg]) : super(msg ?? 'Cancelled', 1);
}

class UnknownException extends ApiException {
  const UnknownException([String? msg]) : super(msg ?? 'Unknown', 2);
}

class AlreadyExistsException extends ApiException {
  const AlreadyExistsException([String? msg])
    : super(msg ?? 'Already exists', 6);
}

class AbortedException extends ApiException {
  const AbortedException([String? msg]) : super(msg ?? 'Aborted', 10);
}

class OutOfRangeException extends ApiException {
  const OutOfRangeException([String? msg]) : super(msg ?? 'Out of range', 11);
}

class UnimplementedException extends ApiException {
  const UnimplementedException([String? msg])
    : super(msg ?? 'Unimplemented', 12);
}

class UnavailableException extends ApiException {
  const UnavailableException([String? msg]) : super(msg ?? 'Unavailable', 14);
}

class DataLossException extends ApiException {
  const DataLossException([String? msg]) : super(msg ?? 'Data loss', 15);
}

class FailedPreconditionException extends ApiException {
  const FailedPreconditionException([String? msg])
    : super(msg ?? 'Failed precondition', 9);
}

// ============================================================
// Platform Detection
// ============================================================

const bool _kIsWeb = bool.fromEnvironment(
  'dart.library.js_interop',
  defaultValue: false,
);

// ============================================================
// Cancel Token
// ============================================================

class RpcCancelToken {
  bool _isCancelled = false;
  final List<void Function()> _callbacks = [];
  Object? _cancelledReason;

  bool get isCancelled => _isCancelled;
  Object? get cancelledReason => _cancelledReason;

  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }

  void cancel([Object? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelledReason = reason;
    for (final cb in _callbacks) {
      cb();
    }
    _callbacks.clear();
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw RpcCancelledException(_cancelledReason);
    }
  }
}

class RpcCancelledException implements Exception {
  final Object? reason;

  const RpcCancelledException([this.reason]);

  @override
  String toString() =>
      'RpcCancelledException\${reason != null ? ': \$reason' : ''}';
}

// ============================================================
// Call Options
// ============================================================

class RpcCallOptions {
  final Map<String, String>? headers;
  final Duration? timeout;
  final String? httpPath;
  final String? httpMethod;
  final Map<String, dynamic>? httpQueryParams;
  final dynamic httpBody;
  final RpcCancelToken? cancelToken;

  RpcCallOptions copyWith({
    Map<String, String>? headers,
    Duration? timeout,
    String? httpPath,
    String? httpMethod,
    Map<String, dynamic>? httpQueryParams,
    dynamic httpBody,
    RpcCancelToken? cancelToken,
  }) {
    return RpcCallOptions(
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      httpPath: httpPath ?? this.httpPath,
      httpMethod: httpMethod ?? this.httpMethod,
      httpQueryParams: httpQueryParams ?? this.httpQueryParams,
      httpBody: httpBody ?? this.httpBody,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }

  const RpcCallOptions({
    this.headers,
    this.timeout,
    this.httpPath,
    this.httpMethod,
    this.httpQueryParams,
    this.httpBody,
    this.cancelToken,
  });
}

// ============================================================
// Interceptor Context & Interface
// ============================================================

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

// ============================================================
// Client Configuration
// ============================================================

enum Protocol { auto, http, grpc }

class ClientOptions {
  final String endpoint;
  final Protocol protocol;
  final Duration? timeout;
  final List<RpcInterceptor> interceptors;
  final RetryPolicy? retryPolicy;
  final bool tracingEnabled;
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

// ============================================================
// Retry Policy
// ============================================================

class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final double jitterFactor;
  final bool Function(Object error)? retryIf;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.25,
    this.retryIf,
  });

  static const RetryPolicy defaultPolicy = RetryPolicy();

  bool shouldRetry(Object error) {
    if (retryIf != null) return retryIf!(error);
    return _defaultRetryIf(error);
  }

  static bool _defaultRetryIf(Object error) {
    final code = _extractCode(error);
    if (code == null) return true;
    return code == 14 || code == 8 || code == 4;
  }

  static int? _extractCode(Object error) {
    try {
      final dynamic d = error;
      final c = d.code;
      if (c is int) return c;
    } catch (_) {}
    return null;
  }

  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;
    var delay =
        initialDelay.inMicroseconds *
        pow(backoffMultiplier, attempt - 1).toDouble();
    if (delay > maxDelay.inMicroseconds) {
      delay = maxDelay.inMicroseconds.toDouble();
    }
    if (jitterFactor > 0) {
      final jitter = delay * jitterFactor * (Random().nextDouble() * 2 - 1);
      delay = (delay + jitter).clamp(0, maxDelay.inMicroseconds.toDouble());
    }
    return Duration(microseconds: delay.round());
  }
}

// ============================================================
// Transport — Unified (dio only, no dart:io)
// ============================================================

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

/// Abstract interface for gRPC client delegation.
///
/// Implementations wrap generated *ServiceClient classes from
/// protoc_plugin (pbgrpc.dart) to provide typed gRPC calls
/// through the interceptor chain.
abstract class GrpcClient {
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

  Future<T> _rawUnaryCall<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
  ) async {
    try {
      final method = options?.httpMethod ?? 'POST';
      final path = options?.httpPath ?? '/\$serviceName/\$methodName';
      final data = options?.httpBody;
      final queryParameters = options?.httpQueryParams;

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
    if (_kIsWeb) {
      throw UnimplementedError('HTTP server streaming not available on web');
    }
    return _sseStream<T>(serviceName, methodName, request, options);
  }

  Stream<T> _sseStream<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
  ) {
    final controller = StreamController<T>();
    final path = options?.httpPath ?? '/\$serviceName/\$methodName';

    final queryParams = <String, dynamic>{};
    if (options?.httpQueryParams != null) {
      queryParams.addAll(options!.httpQueryParams!);
    }

    final headers = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
    if (options?.headers != null) {
      headers.addAll(options!.headers!);
    }

    _dio
        .request<ResponseBody>(
          path,
          data: options?.httpBody,
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
          options: Options(
            method: options?.httpMethod?.toUpperCase() ?? 'GET',
            responseType: ResponseType.stream,
            headers: headers,
            sendTimeout: options?.timeout,
            receiveTimeout: options?.timeout,
          ),
        )
        .then((response) {
          if (response.statusCode != 200) {
            controller.addError(
              InternalServerException(
                'SSE connection failed with status \${response.statusCode}',
              ),
            );
            controller.close();
            return;
          }
          final body = response.data;
          if (body == null) {
            controller.close();
            return;
          }
          SseParser.parse(body.stream).listen(
            (data) => controller.add(data as T),
            onError: controller.addError,
            onDone: controller.close,
          );
        })
        .catchError((Object e, StackTrace st) {
          controller.addError(e, st);
        });

    return controller.stream;
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

// ============================================================
// SSE Parser
// ============================================================

class SseParser {
  static Stream<String> parse(Stream<List<int>> byteStream) async* {
    final buffer = StringBuffer();
    await for (final chunk in byteStream) {
      buffer.write(utf8.decode(chunk));
      final content = buffer.toString();
      final events = _splitEvents(content);
      buffer.clear();
      if (events.remainder.isNotEmpty) {
        buffer.write(events.remainder);
      }
      for (final data in events.dataLines) {
        if (data.isNotEmpty) yield data;
      }
    }
    final remaining = buffer.toString();
    if (remaining.isNotEmpty) {
      final data = _extractData(remaining);
      if (data != null && data.isNotEmpty) yield data;
    }
  }

  static _SplitResult _splitEvents(String content) {
    final dataLines = <String>[];
    var remainder = content;

    normalized() =>
        content.replaceAll('\\r\\n', '\\n').replaceAll('\\r', '\\n');

    final normalizedContent = normalized();
    final parts = normalizedContent.split('\\n\\n');

    for (var i = 0; i < parts.length - 1; i++) {
      final data = _extractData(parts[i]);
      if (data != null) dataLines.add(data);
    }

    remainder = parts.last;

    return _SplitResult(dataLines, remainder);
  }

  static String? _extractData(String eventBlock) {
    final lines = eventBlock.split('\\n');
    final dataLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('data:')) {
        final value = trimmed.substring(5).trim();
        dataLines.add(value);
      }
    }
    if (dataLines.isEmpty) return null;
    return dataLines.join('\\n');
  }
}

class _SplitResult {
  final List<String> dataLines;
  final String remainder;
  _SplitResult(this.dataLines, this.remainder);
}

// ============================================================
// Built-in Interceptors
// ============================================================

class TracingInterceptor implements RpcInterceptor {
  final String Function()? _traceIdProvider;
  final String Function()? _parentIdProvider;

  const TracingInterceptor()
    : _traceIdProvider = null,
      _parentIdProvider = null;

  const TracingInterceptor.withProviders({
    required String Function() traceIdProvider,
    required String Function() parentIdProvider,
  }) : _traceIdProvider = traceIdProvider,
       _parentIdProvider = parentIdProvider;

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    final traceparent = _buildTraceparent();
    final existingHeaders = context.options?.headers ?? {};
    final updatedHeaders = Map<String, String>.from(existingHeaders);
    updatedHeaders['traceparent'] = traceparent;
    final baseOptions = context.options ?? RpcCallOptions();
    final updatedOptions = baseOptions.copyWith(headers: updatedHeaders);
    final updatedContext = context.copyWith(options: updatedOptions);
    return proceed(updatedContext);
  }

  String _buildTraceparent() {
    final traceId = _traceIdProvider != null
        ? _traceIdProvider()
        : _generateHex(32);
    final parentId = _parentIdProvider != null
        ? _parentIdProvider()
        : _generateHex(16);
    return '00-\$traceId-\$parentId-01';
  }

  static String _generateHex(int length) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}

class RetryInterceptor implements RpcInterceptor {
  final RetryPolicy _policy;

  const RetryInterceptor([this._policy = RetryPolicy.defaultPolicy]);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _policy.maxAttempts; attempt++) {
      try {
        return await proceed(context);
      } on ApiException catch (e) {
        lastError = e;
        if (attempt >= _policy.maxAttempts || !_policy.shouldRetry(e)) {
          rethrow;
        }
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt >= _policy.maxAttempts) rethrow;
      }
      final delay = _policy.delayForAttempt(attempt + 1);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
    throw lastError ?? InternalServerException('Retry exhausted');
  }
}

typedef RpcLogger = void Function(String message);

class LoggingInterceptor implements RpcInterceptor {
  final RpcLogger _logger;

  const LoggingInterceptor(this._logger);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    final serviceName = context.serviceName;
    final methodName = context.methodName;
    _logger('\u2192 \$serviceName/\$methodName');
    try {
      final result = await proceed(context);
      _logger('\u2190 \$serviceName/\$methodName OK');
      return result;
    } catch (e) {
      _logger('\u2190 \$serviceName/\$methodName ERROR: \$e');
      rethrow;
    }
  }
}

typedef TokenProvider = Future<String?> Function();

class AuthInterceptor implements RpcInterceptor {
  final TokenProvider _tokenProvider;
  final String _headerKey;

  const AuthInterceptor(
    this._tokenProvider, {
    String headerKey = 'authorization',
  }) : _headerKey = headerKey;

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      final existingHeaders = context.options?.headers ?? {};
      final updatedHeaders = Map<String, String>.from(existingHeaders);
      updatedHeaders[_headerKey] =
          token.startsWith('Bearer ') ? token : 'Bearer \$token';
      final baseOptions = context.options ?? RpcCallOptions();
      final updatedOptions = baseOptions.copyWith(headers: updatedHeaders);
      final updatedContext = context.copyWith(options: updatedOptions);
      return proceed(updatedContext);
    }
    return proceed(context);
  }
}

// ============================================================
// Utilities
// ============================================================

Future<T> withRetry<T>(
  Future<T> Function() fn,
  RetryPolicy policy, {
  bool Function(Object error)? shouldRetry,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt <= policy.maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      lastError = e;
      if (attempt >= policy.maxAttempts) rethrow;
      final retryPredicate = shouldRetry ?? policy.shouldRetry;
      if (!retryPredicate(e)) rethrow;
      final delay = policy.delayForAttempt(attempt + 1);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
  }
  throw lastError ?? Exception('Retry exhausted');
}
''';
  }

  /// Returns the source for `unified_transport_factory.dart`.
  ///
  /// A conditional-import dispatcher that selects the platform-specific
  /// transport factory, mirroring `lib/src/runtime/transport_factory.dart`.
  /// It imports [unified_runtime] for the shared types so the [Transport]
  /// returned here is the same type the generated service files use.
  String generateTransportFactory() {
    return '''
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
// DO NOT EDIT: Platform transport factory dispatcher for the unified RPC SDK.

import 'unified_runtime.dart';
import 'unified_transport_stub.dart'
    if (dart.library.io) 'unified_transport_native.dart'
    if (dart.library.js_interop) 'unified_transport_web.dart' as impl;

Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
  Protocol protocol = Protocol.auto,
}) => impl.createTransport(
      endpoint,
      grpcClient: grpcClient,
      interceptors: interceptors,
      protocol: protocol,
    );
''';
  }

  /// Returns the source for `unified_transport_native.dart`.
  ///
  /// Native-only transport factory: gRPC ([GrpcTransport] delegating to a
  /// [GrpcClient]) when a [GrpcClient] is available, otherwise HTTP
  /// ([HttpTransport]). This file is GLOBAL and always present so the
  /// conditional-import factory (`unified_transport_factory.dart`) keeps a
  /// stable import target. Per-service gRPC method dispatch lives in the
  /// generated `unified_transport_adapter_{service}.dart` files instead.
  String generateTransportNative() {
    return '''
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
// DO NOT EDIT: Native transport factory (gRPC + HTTP) for the unified RPC SDK.

import 'dart:async';
import 'package:grpc/grpc.dart';
import 'unified_runtime.dart';

/// gRPC transport implementation that delegates to a [GrpcClient].
///
/// The [GrpcClient] is supplied by the generated per-service adapter
/// (`unified_transport_adapter_{service}.dart`), which wraps the real
/// generated `*ServiceClient`. This keeps the global native file free of any
/// per-service / generated gRPC client dependency (web-safety red line).
class GrpcTransport extends Transport {
  final GrpcClient _client;
  final List<RpcInterceptor> _interceptors;

  GrpcTransport(this._client, {List<RpcInterceptor> interceptors = const []})
    : _interceptors = interceptors;

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
      (req, opts) => _rawGrpcUnaryCall<T>(serviceName, methodName, req, opts),
    );
  }

  Future<T> _rawGrpcUnaryCall<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
  ) async {
    final rf = _client.unaryCall<T>(
      serviceName,
      methodName,
      request,
      options: options,
    );
    // Bridge the unified cancel token onto the gRPC ResponseFuture.
    if (options?.cancelToken != null) {
      options!.cancelToken!.onCancel(() => (rf as dynamic).cancel());
    }
    try {
      return await rf;
    } on GrpcError catch (e) {
      throw _mapGrpcError(e);
    }
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    final stream = _client.serverStream<T>(
      serviceName,
      methodName,
      request,
      options: options,
    );
    return stream.handleError(
      (Object e) {
        if (e is GrpcError) throw _mapGrpcError(e);
      },
      test: (e) => e is GrpcError,
    );
  }
}

/// Maps a gRPC [GrpcError] to the unified [ApiException] hierarchy.
ApiException _mapGrpcError(GrpcError e) {
  final message = e.message ?? 'gRPC error';
  return switch (e.code) {
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

Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
  Protocol protocol = Protocol.auto,
}) {
  final useGrpc = switch (protocol) {
    Protocol.grpc => true,
    Protocol.http => false,
    Protocol.auto => grpcClient != null,
  };
  if (useGrpc && grpcClient != null) {
    return GrpcTransport(grpcClient, interceptors: interceptors);
  }
  return HttpTransport(endpoint, interceptors: interceptors);
}
''';
  }

  /// Returns the source for `unified_transport_adapter_{service}.dart`.
  ///
  /// Per-service gRPC adapter: wraps the generated `*ServiceClient` (from
  /// `*pbgrpc.dart`) and implements [GrpcClient] by dispatching each method
  /// name to the matching named client method. This file carries the only
  /// pbgrpc import in the generated output, keeping the global runtime and
  /// the per-service SDK files web-safe.
  String generateTransportAdapter(ServiceModel service) {
    final serviceName = service.name;
    final protoBase = service.protoFileName.replaceAll('.proto', '');
    final clientClass = '${serviceName}Client';
    final adapterClass = '${serviceName}GrpcAdapter';

    final unaryCases = StringBuffer();
    final streamCases = StringBuffer();
    for (final method in service.methods) {
      final camel = _dartMethodName(method.name);
      final inputType = method.inputType;
      if (method.isServerStreaming) {
        streamCases.writeln('    case \'$camel\':');
        streamCases.writeln(
          '      return _client.$camel(request as $inputType, '
          'options: callOptions) as Stream<T>;',
        );
      } else {
        unaryCases.writeln('    case \'$camel\':');
        unaryCases.writeln(
          '      return _client.$camel(request as $inputType, '
          'options: callOptions) as Future<T>;',
        );
      }
    }

    return '''
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
// DO NOT EDIT: Per-service gRPC adapter for the unified RPC SDK.

import 'dart:async';
import 'package:grpc/grpc.dart';
import 'unified_runtime.dart';
import '$protoBase.pbgrpc.dart';

/// Adapts the generated [$clientClass] to the [GrpcClient] interface consumed
/// by [GrpcTransport]. Pass an instance to [ApiSdk] via the `grpcClient`
/// parameter on native platforms.
class $adapterClass implements GrpcClient {
  final $clientClass _client;

  $adapterClass(this._client);

  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    final callOptions = _toCallOptions(options);
    switch (methodName) {
$unaryCases
      default:
        throw ArgumentError('Unknown method: \$methodName');
    }
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    final callOptions = _toCallOptions(options);
    switch (methodName) {
$streamCases
      default:
        throw ArgumentError('Unknown method: \$methodName');
    }
  }
}

/// Maps unified [RpcCallOptions] to gRPC [CallOptions].
CallOptions _toCallOptions(RpcCallOptions? options) {
  if (options == null) return CallOptions();
  return CallOptions(
    metadata: options.headers ?? const {},
    timeout: options.timeout,
  );
}
''';
  }

  /// Converts a proto PascalCase name to a Dart camelCase name.
  String _dartMethodName(String protoName) {
    if (protoName.isEmpty) return protoName;
    return protoName[0].toLowerCase() + protoName.substring(1);
  }

  /// Returns the source for `unified_transport_web.dart`.
  ///
  /// Web-only transport factory: HTTP ([HttpTransport]) only. A non-null
  /// [GrpcClient] is rejected because pure gRPC is unavailable on the web.
  String generateTransportWeb() {
    return '''
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
// DO NOT EDIT: Web transport factory (HTTP only) for the unified RPC SDK.

import 'unified_runtime.dart';

Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
  Protocol protocol = Protocol.auto,
}) {
  if (grpcClient != null) {
    throw UnsupportedError(
      'Web platform does not support pure gRPC services. Add google.api.http '
      'annotations to enable HTTP/REST, or use a native platform.',
    );
  }
  return HttpTransport(endpoint, interceptors: interceptors);
}
''';
  }

  /// Returns the source for `unified_transport_stub.dart`.
  ///
  /// Fallback for platforms that support neither `dart:io` nor
  /// `dart.library.js_interop`.
  String generateTransportStub() {
    return '''
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
// DO NOT EDIT: Stub transport factory for unsupported platforms.

import 'unified_runtime.dart';

Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
  Protocol protocol = Protocol.auto,
}) => throw UnsupportedError('Platform not supported');
''';
  }
}
