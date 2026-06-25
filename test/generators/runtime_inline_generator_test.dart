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
      expect(code, contains('Transport? createTransport'));
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
      final code = generator.generate();
      final tempDir = Directory.systemTemp.createTempSync(
        'unified_runtime_test',
      );
      try {
        // Write the generated file
        File('${tempDir.path}/unified_runtime.dart').writeAsStringSync(code);

        // Write a minimal pubspec with dio dependency
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: runtime_test
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  dio: ^5.9.0
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
  });
}
