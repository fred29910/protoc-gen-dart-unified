import 'dart:io';

import 'package:test/test.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/http.pb.dart' as http_rule;
import 'package:protoc_gen_dart_unified/src/parser/google/api/annotations.pb.dart' as api_annotations;

// Compile-level proof of web isolation: the generated file set that a web
// build actually compiles (everything except the native-only files) must
// analyze clean WITHOUT `dart:io` or `package:grpc` resolving. The native
// transport (`*_transport_native.dart`) and the per-service gRPC adapter
// (`*_transport_adapter_*.dart`) are the only files allowed to touch grpc /
// dart:io, and they are excluded from web compilation by conditional imports.
void main() {
  group('web gRPC isolation', () {
    test('web-safe generated file set compiles without grpc/dart:io', () async {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'UserService'
            ..method.addAll([
              MethodDescriptorProto()
                ..name = 'GetUser'
                ..inputType = '.user.v1.GetUserRequest'
                ..outputType = '.user.v1.User'
                ..options = _buildHttpOptions('get', '/v1/users/{id}'),
              MethodDescriptorProto()
                ..name = 'ListUsers'
                ..inputType = '.user.v1.ListUsersRequest'
                ..outputType = '.user.v1.User'
                ..serverStreaming = true
                ..options = _buildHttpOptions('get', '/v1/users'),
            ]),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(
          fileToGenerate: ['user.proto'],
          protoFile: [file],
          parameter: 'mock=false',
        ),
      );
      expect(response.error, isEmpty,
          reason: 'generator reported errors: ${response.error}');

      // Web build compiles every generated file EXCEPT the native-only set.
      final webFiles = response.file.where((f) {
        final name = f.name;
        return !name.endsWith('_transport_native.dart') &&
            !name.contains('_transport_adapter_');
      });

      // Sanity: the native + adapter files must exist (they are the only
      // grpc/dart:io carriers) so that excluding them is meaningful.
      final hasNative = response.file
          .any((f) => f.name.endsWith('_transport_native.dart'));
      final hasAdapter = response.file
          .any((f) => f.name.contains('_transport_adapter_'));
      expect(hasNative, isTrue,
          reason: 'native transport file should be generated');
      expect(hasAdapter, isTrue,
          reason: 'per-service adapter file should be generated');

      final tempDir = Directory.systemTemp.createTempSync('web_iso');
      try {
        for (final f in webFiles) {
          File('${tempDir.path}/${f.name}').writeAsStringSync(f.content);
        }
        // The service file references generated protobuf message types via
        // `user.pb.dart`. Provide minimal stubs so the web set (which must
        // NOT pull in grpc/pbgrpc) can be analyzed in isolation. The native
        // transport + per-service adapter are excluded, so no pbgrpc stub is
        // needed here.
        File('${tempDir.path}/user.pb.dart').writeAsStringSync('''
class User {}
class GetUserRequest {
  String get id => '';
}
class ListUsersRequest {}
''');
        // The web set imports `package:protobuf` (via *.pb.dart) and
        // `package:dio` (HTTP transport). grpc is intentionally absent.
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: web_iso
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  dio: ^5.9.0
  protobuf: ^3.1.0
''');

        final pubGet = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: tempDir.path,
        );
        expect(pubGet.exitCode, 0,
            reason: 'dart pub get failed:\n${pubGet.stderr}');

        final result = await Process.run(
          'dart',
          ['analyze', '--fatal-infos'],
          workingDirectory: tempDir.path,
        );
        expect(result.exitCode, 0,
            reason: 'web-safe set failed analysis '
                '(grpc/dart:io leaked into web build):\n'
                '${result.stdout}\n${result.stderr}');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generated web files never import grpc, dart:io, or pbgrpc', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'UserService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'GetUser'
                ..inputType = '.user.v1.GetUserRequest'
                ..outputType = '.user.v1.User'
                ..options = _buildHttpOptions('get', '/v1/users/{id}'),
            ),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(
          fileToGenerate: ['user.proto'],
          protoFile: [file],
          parameter: 'mock=false',
        ),
      );

      // Only the native transport + per-service adapter may reference grpc /
      // dart:io / pbgrpc. Every other file is web-safe. We check for actual
      // `import` directives only — doc comments mentioning pbgrpc are fine.
      final importsPbgrpc = RegExp(r"import\s+'[^']*pbgrpc\.dart'");
      for (final f in response.file) {
        final isNativeOnly = f.name.endsWith('_transport_native.dart') ||
            f.name.contains('_transport_adapter_');
        if (isNativeOnly) continue;

        expect(f.content, isNot(contains("import 'package:grpc/grpc.dart'")),
            reason: '${f.name} must not import grpc (web-unsafe)');
        expect(f.content, isNot(contains("import 'dart:io'")),
            reason: '${f.name} must not import dart:io (web-unsafe)');
        expect(importsPbgrpc.hasMatch(f.content), isFalse,
            reason: '${f.name} must not import pbgrpc (web-unsafe)');
      }
    });
  });
}

MethodOptions _buildHttpOptions(
  String httpMethod,
  String path, {
  String body = '',
}) {
  final httpRuleMsg = http_rule.HttpRule();
  switch (httpMethod) {
    case 'get':
      httpRuleMsg.get = path;
      break;
    case 'post':
      httpRuleMsg.post = path;
      break;
    case 'put':
      httpRuleMsg.put = path;
      break;
    case 'delete':
      httpRuleMsg.delete = path;
      break;
    case 'patch':
      httpRuleMsg.patch = path;
      break;
  }
  if (body.isNotEmpty) {
    httpRuleMsg.body = body;
  }
  final options = MethodOptions();
  options.setExtension(api_annotations.Annotations.http, httpRuleMsg);
  return options;
}
