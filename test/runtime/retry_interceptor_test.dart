import 'dart:async';
import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/retry_interceptor.dart';
import 'package:protoc_gen_dart_unified/src/runtime/retry_policy.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_interceptor.dart';
import 'package:protoc_gen_dart_unified/src/runtime/api_exception.dart';

void main() {
  group('RetryInterceptor', () {
    test('succeeds on first attempt without retry', () async {
      const interceptor = RetryInterceptor();
      var callCount = 0;

      Future<String> proceed(InterceptorContext ctx) async {
        callCount++;
        return 'ok';
      }

      final result = await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(result, equals('ok'));
      expect(callCount, equals(1));
    });

    test('retries on UNAVAILABLE and eventually succeeds', () async {
      const interceptor = RetryInterceptor(
        RetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
          jitterFactor: 0,
        ),
      );
      var callCount = 0;

      Future<String> proceed(InterceptorContext ctx) async {
        callCount++;
        if (callCount < 3) {
          throw const UnavailableException('server unavailable');
        }
        return 'ok';
      }

      final result = await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(result, equals('ok'));
      expect(callCount, equals(3));
    });

    test('gives up after maxAttempts', () async {
      const interceptor = RetryInterceptor(
        RetryPolicy(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 1),
          jitterFactor: 0,
        ),
      );
      var callCount = 0;

      Future<String> proceed(InterceptorContext ctx) async {
        callCount++;
        throw const UnavailableException('server unavailable');
      }

      try {
        await interceptor.intercept(
          const InterceptorContext(
            serviceName: 'TestService',
            methodName: 'TestMethod',
            request: 'request',
          ),
          proceed,
        );
        fail('Should have thrown');
      } on UnavailableException {
        // Expected: initial attempt + 2 retries = 3 total
        expect(callCount, equals(3));
      }
    });

    test('does not retry on non-retryable errors', () async {
      const interceptor = RetryInterceptor(
        RetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
          jitterFactor: 0,
        ),
      );
      var callCount = 0;

      Future<String> proceed(InterceptorContext ctx) async {
        callCount++;
        throw const InvalidArgumentException('bad input');
      }

      try {
        await interceptor.intercept(
          const InterceptorContext(
            serviceName: 'TestService',
            methodName: 'TestMethod',
            request: 'request',
          ),
          proceed,
        );
        fail('Should have thrown');
      } on InvalidArgumentException {
        expect(callCount, equals(1));
      }
    });

    test('retries on TimeoutException', () async {
      const interceptor = RetryInterceptor(
        RetryPolicy(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 1),
          jitterFactor: 0,
        ),
      );
      var callCount = 0;

      Future<String> proceed(InterceptorContext ctx) async {
        callCount++;
        if (callCount < 2) {
          throw TimeoutException('timeout', const Duration(seconds: 1));
        }
        return 'ok';
      }

      final result = await interceptor.intercept(
        const InterceptorContext(
          serviceName: 'TestService',
          methodName: 'TestMethod',
          request: 'request',
        ),
        proceed,
      );

      expect(result, equals('ok'));
      expect(callCount, equals(2));
    });
  });
}
