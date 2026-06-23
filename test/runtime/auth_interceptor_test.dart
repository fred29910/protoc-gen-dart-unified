import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/auth_interceptor.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_interceptor.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_call_options.dart';

void main() {
  group('AuthInterceptor', () {
    test('injects Bearer token into headers', () async {
      const interceptor = AuthInterceptor(_fixedToken);
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(capturedHeaders['authorization'], equals('Bearer test-token'));
    });

    test('adds Bearer prefix when missing', () async {
      const interceptor = AuthInterceptor(_plainToken);
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(capturedHeaders['authorization'], equals('Bearer plain-token'));
    });

    test('preserves Bearer prefix when already present', () async {
      const interceptor = AuthInterceptor(_bearerToken);
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(capturedHeaders['authorization'], equals('Bearer already-bearer'));
    });

    test('uses custom header key', () async {
      const interceptor = AuthInterceptor(_fixedToken, headerKey: 'x-api-key');
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(capturedHeaders['x-api-key'], equals('Bearer test-token'));
      expect(capturedHeaders.containsKey('authorization'), isFalse);
    });

    test('preserves existing headers', () async {
      const interceptor = AuthInterceptor(_fixedToken);
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
          options: RpcCallOptions(headers: {'X-Custom': 'value'}),
        ),
        proceed,
      );

      expect(capturedHeaders['authorization'], equals('Bearer test-token'));
      expect(capturedHeaders['X-Custom'], equals('value'));
    });

    test('does not inject when token is null', () async {
      const interceptor = AuthInterceptor(_nullToken);
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(capturedHeaders.containsKey('authorization'), isFalse);
    });

    test('does not inject when token is empty', () async {
      const interceptor = AuthInterceptor(_emptyToken);
      var capturedHeaders = <String, String>{};

      Future<String> proceed(InterceptorContext ctx) async {
        capturedHeaders = ctx.options?.headers ?? {};
        return 'ok';
      }

      await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(capturedHeaders.containsKey('authorization'), isFalse);
    });
  });
}

Future<String?> _fixedToken() async => 'test-token';
Future<String?> _plainToken() async => 'plain-token';
Future<String?> _bearerToken() async => 'Bearer already-bearer';
Future<String?> _nullToken() async => null;
Future<String?> _emptyToken() async => '';
