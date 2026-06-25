import 'rpc_interceptor.dart';
import 'rpc_call_options.dart';

/// Provides authentication tokens for request headers/metadata.
typedef TokenProvider = Future<String?> Function();

/// Interceptor that injects authentication tokens into requests.
///
/// Works for both HTTP (headers) and gRPC (metadata) transports.
class AuthInterceptor implements RpcInterceptor {
  final TokenProvider _tokenProvider;
  final String _headerKey;

  /// Creates an auth interceptor.
  ///
  /// [tokenProvider] supplies the token value.
  /// [headerKey] is the header/metadata key (default: 'authorization').
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
      updatedHeaders[_headerKey] = token.startsWith('Bearer ')
          ? token
          : 'Bearer $token';
      final baseOptions = context.options ?? RpcCallOptions();
      final updatedOptions = baseOptions.copyWith(headers: updatedHeaders);
      final updatedContext = context.copyWith(options: updatedOptions);
      return proceed(updatedContext);
    }
    return proceed(context);
  }
}
