import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/tracing_interceptor.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_interceptor.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_call_options.dart';

void main() {
  group('TracingInterceptor', () {
    test('injects traceparent header', () async {
      const interceptor = TracingInterceptor();
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
          options: RpcCallOptions(),
        ),
        proceed,
      );

      expect(capturedHeaders.containsKey('traceparent'), isTrue);
      final traceparent = capturedHeaders['traceparent']!;
      expect(traceparent.startsWith('00-'), isTrue);
      // Format: 00-{32 hex}-{16 hex}-01
      final parts = traceparent.split('-');
      expect(parts.length, equals(4));
      expect(parts[0], equals('00'));
      expect(parts[1].length, equals(32));
      expect(parts[2].length, equals(16));
      expect(parts[3], equals('01'));
    });

    test('preserves existing headers', () async {
      const interceptor = TracingInterceptor();
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
          options: RpcCallOptions(headers: {'Authorization': 'Bearer token'}),
        ),
        proceed,
      );

      expect(capturedHeaders['Authorization'], equals('Bearer token'));
      expect(capturedHeaders.containsKey('traceparent'), isTrue);
    });

    test('uses custom trace/parent ID providers', () async {
      const interceptor = TracingInterceptor.withProviders(
        traceIdProvider: _fixedTraceId,
        parentIdProvider: _fixedParentId,
      );
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

      expect(
        capturedHeaders['traceparent'],
        equals('00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01'),
      );
    });

    test('generates unique trace IDs per call', () async {
      const interceptor = TracingInterceptor();
      final traceIds = <String>{};

      for (var i = 0; i < 10; i++) {
        Future<String> proceed(InterceptorContext ctx) async {
          final tp = ctx.options?.headers?['traceparent'] ?? '';
          traceIds.add(tp.split('-')[1]);
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
      }

      // All 10 trace IDs should be unique
      expect(traceIds.length, equals(10));
    });
  });
}

String _fixedTraceId() => 'a' * 32;
String _fixedParentId() => 'b' * 16;
