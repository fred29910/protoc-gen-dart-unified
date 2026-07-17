import 'dart:io';

import 'package:protoc_gen_dart_unified/src/generators/runtime_inline_generator.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeInlineGenerator', () {
    late RuntimeInlineGenerator generator;

    setUp(() {
      generator = RuntimeInlineGenerator();
    });

    test('generates compilable runtime code', () {
      final code = generator.generate();

      // Header
      expect(code, contains('GENERATED_BY'));
      expect(code, contains('DO NOT EDIT'));

      // Only allowed imports
      expect(code, contains("import 'package:dio/dio.dart'"));
      expect(code, contains("import 'dart:async'"));
      expect(code, contains("import 'dart:convert'"));
      expect(code, contains("import 'dart:math' show pow, Random;"));
      expect(code, isNot(contains("import 'dart:io'")));
      expect(code, isNot(contains("import 'dart:html'")));

      // Exception hierarchy (17 classes: ApiException + 16 subclasses)
      expect(code, contains('class ApiException'));
      expect(code, contains('class InvalidArgumentException'));
      expect(code, contains('class UnauthenticatedException'));
      expect(code, contains('class PermissionDeniedException'));
      expect(code, contains('class NotFoundException'));
      expect(code, contains('class ResourceExhaustedException'));
      expect(code, contains('class InternalServerException'));
      expect(code, contains('class RpcTimeoutException'));
      expect(code, contains('class CancelledException'));
      expect(code, contains('class UnknownException'));
      expect(code, contains('class AlreadyExistsException'));
      expect(code, contains('class AbortedException'));
      expect(code, contains('class OutOfRangeException'));
      expect(code, contains('class UnimplementedException'));
      expect(code, contains('class UnavailableException'));
      expect(code, contains('class DataLossException'));
      expect(code, contains('class FailedPreconditionException'));

      // Core types
      expect(code, contains('class RpcCancelToken'));
      expect(code, contains('class RpcCancelledException'));
      expect(code, contains('class RpcCallOptions'));
      expect(code, contains('class InterceptorContext'));
      expect(code, contains('abstract class RpcInterceptor'));
      expect(code, contains('enum Protocol'));
      expect(code, contains('class ClientOptions'));
      expect(code, contains('class RetryPolicy'));

      // Transport
      expect(code, contains('abstract class Transport'));
      expect(code, contains('class HttpTransport'));
      expect(code, contains('_kIsWeb'));

      // SSE
      expect(code, contains('class SseParser'));

      // Interceptors
      expect(code, contains('class TracingInterceptor'));
      expect(code, contains('class RetryInterceptor'));
      expect(code, contains('class LoggingInterceptor'));
      expect(code, contains('class AuthInterceptor'));

      // Utilities
      expect(code, contains('Future<T> withRetry'));
      expect(code, contains('typedef RpcLogger'));
      expect(code, contains('typedef TokenProvider'));
    });

    test('generated runtime code passes dart analyze', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'unified_runtime_test',
      );
      try {
        // Write the full generated runtime set. unified_runtime.dart now
        // re-exports the conditional-import transport factory, so the factory
        // and its platform files must be present for analysis.
        final files = {
          'unified_runtime.dart': generator.generate(),
          'unified_transport_factory.dart':
              generator.generateTransportFactory(),
          'unified_transport_native.dart':
              generator.generateTransportNative(),
          'unified_transport_web.dart': generator.generateTransportWeb(),
          'unified_transport_stub.dart': generator.generateTransportStub(),
        };
        files.forEach((name, content) {
          File('${tempDir.path}/$name').writeAsStringSync(content);
        });

        // Write a minimal pubspec with dio + grpc dependencies.
        // unified_runtime.dart re-exports the transport factory, which on the
        // native analyzer platform conditionally pulls in the gRPC native file.
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: runtime_test
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  dio: ^5.9.0
  grpc: ^5.1.0
''');

        // Run pub get
        final pubGetResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: tempDir.path,
        );
        expect(
          pubGetResult.exitCode,
          0,
          reason: 'dart pub get failed:\n${pubGetResult.stderr}',
        );

        // Run analyze
        final result = await Process.run(
          'dart',
          ['analyze', '--fatal-infos'],
          workingDirectory: tempDir.path,
        );
        expect(
          result.exitCode,
          0,
          reason: 'dart analyze failed:\n${result.stdout}\n${result.stderr}',
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('web-grpc-isolation (approach A1)', () {
      test('generate() strips gRPC transport and re-exports factory', () {
        final code = generator.generate();

        // gRPC / dart:io must be gone from the platform-agnostic runtime.
        expect(code, isNot(contains('class GrpcTransport')));
        expect(code, isNot(contains("import 'package:grpc/grpc.dart'")));
        expect(code, isNot(contains("import 'dart:io'")));
        expect(code, isNot(contains('Transport? createTransport(')));

        // Factory wiring + shared abstract types must remain.
        expect(code, contains("unified_transport_factory.dart"));
        expect(code, contains('abstract class GrpcClient'));
      });

      test('generateTransportFactory() dispatches via conditional imports', () {
        final code = generator.generateTransportFactory();

        expect(
          code,
          contains(
            "if (dart.library.io) 'unified_transport_native.dart'",
          ),
        );
        expect(
          code,
          contains(
            "if (dart.library.js_interop) 'unified_transport_web.dart'",
          ),
        );
        expect(code, contains('Transport? createTransport('));
      });

      test('generateTransportNative() contains gRPC transport + adapter', () {
        final code = generator.generateTransportNative();

        expect(code, contains("import 'package:grpc/grpc.dart'"));
        expect(code, contains('class GrpcTransport'));
        expect(code, contains('class GrpcClientAdapter'));
        expect(code, contains('Transport? createTransport('));
      });

      test('generateTransportWeb() is grpc/dart:io free', () {
        final code = generator.generateTransportWeb();

        expect(code, isNot(contains('package:grpc')));
        expect(code, isNot(contains('dart:io')));
        expect(code, contains('throw UnsupportedError'));
        expect(code, contains('Transport? createTransport('));
      });

      test('generateTransportStub() throws UnsupportedError', () {
        final code = generator.generateTransportStub();

        expect(code, contains('Transport? createTransport('));
        expect(code, contains('throw UnsupportedError'));
      });

      test('generated 5-file set compiles together (dart analyze)', () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'unified_runtime_set_test',
        );
        try {
          final files = {
            'unified_runtime.dart': generator.generate(),
            'unified_transport_factory.dart':
                generator.generateTransportFactory(),
            'unified_transport_native.dart':
                generator.generateTransportNative(),
            'unified_transport_web.dart': generator.generateTransportWeb(),
            'unified_transport_stub.dart': generator.generateTransportStub(),
          };
          files.forEach((name, content) {
            File('${tempDir.path}/$name').writeAsStringSync(content);
          });

          File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: runtime_set_test
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  dio: ^5.9.0
  grpc: ^5.1.0
''');

          final pubGetResult = await Process.run(
            'dart',
            ['pub', 'get'],
            workingDirectory: tempDir.path,
          );
          expect(
            pubGetResult.exitCode,
            0,
            reason: 'dart pub get failed:\n${pubGetResult.stderr}',
          );

          final result = await Process.run(
            'dart',
            ['analyze', '--fatal-infos', 'unified_runtime.dart'],
            workingDirectory: tempDir.path,
          );
          expect(
            result.exitCode,
            0,
            reason: 'dart analyze failed:\n${result.stdout}\n${result.stderr}',
          );

          // Web file must not reference grpc / dart:io even when analyzed
          // together with the native file.
          final web = files['unified_transport_web.dart']!;
          expect(web, isNot(contains('package:grpc')));
          expect(web, isNot(contains('dart:io')));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });
  });
}
