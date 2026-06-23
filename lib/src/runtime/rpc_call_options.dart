/// Options for a single RPC call.
///
/// Carries headers/metadata, timeout/deadline, HTTP-specific
/// path/query/body overrides, and a cancellation signal.
class RpcCallOptions {
  /// HTTP headers or gRPC metadata key-value pairs.
  final Map<String, String>? headers;

  /// Timeout / deadline for the call.
  final Duration? timeout;

  /// HTTP path override (generated code sets this from HttpRule).
  final String? httpPath;

  /// HTTP method override (generated code sets this from HttpRule).
  final String? httpMethod;

  /// HTTP query parameters override.
  final Map<String, dynamic>? httpQueryParams;

  /// HTTP body override.
  final dynamic httpBody;

  /// Creates a copy with the given fields replaced.
  RpcCallOptions copyWith({
    Map<String, String>? headers,
    Duration? timeout,
    String? httpPath,
    String? httpMethod,
    Map<String, dynamic>? httpQueryParams,
    dynamic httpBody,
  }) {
    return RpcCallOptions(
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      httpPath: httpPath ?? this.httpPath,
      httpMethod: httpMethod ?? this.httpMethod,
      httpQueryParams: httpQueryParams ?? this.httpQueryParams,
      httpBody: httpBody ?? this.httpBody,
    );
  }

  const RpcCallOptions({
    this.headers,
    this.timeout,
    this.httpPath,
    this.httpMethod,
    this.httpQueryParams,
    this.httpBody,
  });
}
