import 'dart:io';
import 'package:test/test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:protoc_gen_dart_unified/src/format_formatter.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/annotations.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/http.pb.dart'
    as http_rule;

void main() {
  // Check for --update-goldens flag
  final updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

  group('Golden Tests', () {
    test('generator produces CodeGeneratorResponse', () {
      final request = CodeGeneratorRequest(
        fileToGenerate: ['test/fixtures/user.proto'],
        protoFile: [],
      );
      final generator = CodeGenerator();
      final response = generator.generate(request);
      expect(response.error, isEmpty);
    });

    test('DartFormatter idempotent on generated source', () {
      final source = 'class Foo{int x;}';
      final formatted1 = formatDartSource(source);
      final formatted2 = formatDartSource(formatted1);
      expect(formatted2, equals(formatted1));
    });

    test('generator handles empty request without crash', () {
      final request = CodeGeneratorRequest();
      final generator = CodeGenerator();
      final response = generator.generate(request);
      expect(response.file, isEmpty);
      expect(response.error, isEmpty);
    });

    test('user.proto generates expected user_service.dart', () {
      // Build a FileDescriptorProto matching test/fixtures/user.proto
      final file = _buildUserProtoFile();

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['user.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      // Default mock=true generates 3 files: service + mock + example_test
      expect(response.file, hasLength(3));

      // Verify service file
      final serviceFile = response.file.firstWhere(
        (f) => f.name == 'user_service.dart',
      );
      final goldenFile = File('test/goldens/user_service.dart.golden');

      if (updateGoldens) {
        goldenFile.writeAsStringSync(serviceFile.content);
        print('Golden file updated: ${goldenFile.path}');
      } else {
        expect(
          goldenFile.existsSync(),
          isTrue,
          reason:
              'Golden file not found. Run with UPDATE_GOLDENS=1 to generate.',
        );
        final expectedContent = goldenFile.readAsStringSync();
        expect(
          serviceFile.content,
          equals(expectedContent),
          reason:
              'Generated output does not match golden file. '
              'Run with UPDATE_GOLDENS=1 to update.',
        );
      }
    });

    test('user.proto generates expected user_service_mock.dart', () {
      final file = _buildUserProtoFile();

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['user.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final mockFile = response.file.firstWhere(
        (f) => f.name.endsWith('_mock.dart'),
      );
      final goldenFile = File('test/goldens/user_service_mock.dart.golden');

      if (updateGoldens) {
        goldenFile.writeAsStringSync(mockFile.content);
        print('Golden file updated: ${goldenFile.path}');
      } else {
        expect(
          goldenFile.existsSync(),
          isTrue,
          reason:
              'Golden file not found. Run with UPDATE_GOLDENS=1 to generate.',
        );
        final expectedContent = goldenFile.readAsStringSync();
        expect(
          mockFile.content,
          equals(expectedContent),
          reason:
              'Generated mock output does not match golden file. '
              'Run with UPDATE_GOLDENS=1 to update.',
        );
      }
    });

    test('user.proto generates expected user_service_example_test.dart', () {
      final file = _buildUserProtoFile();

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['user.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final testFile = response.file.firstWhere(
        (f) => f.name.endsWith('_example_test.dart'),
      );
      final goldenFile = File(
        'test/goldens/user_service_example_test.dart.golden',
      );

      if (updateGoldens) {
        goldenFile.writeAsStringSync(testFile.content);
        print('Golden file updated: ${goldenFile.path}');
      } else {
        expect(
          goldenFile.existsSync(),
          isTrue,
          reason:
              'Golden file not found. Run with UPDATE_GOLDENS=1 to generate.',
        );
        final expectedContent = goldenFile.readAsStringSync();
        expect(
          testFile.content,
          equals(expectedContent),
          reason:
              'Generated example_test output does not match golden file. '
              'Run with UPDATE_GOLDENS=1 to update.',
        );
      }
    });

    test('mock=false disables mock and example_test generation', () {
      final file = _buildUserProtoFile();

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(
          fileToGenerate: ['user.proto'],
          protoFile: [file],
          parameter: 'mock=false',
        ),
      );

      expect(response.error, isEmpty);
      expect(response.file, hasLength(1));
      expect(response.file.first.name, equals('user_service.dart'));
    });

    test(
      'golden file compiles successfully',
      () async {
        final goldenFile = File('test/goldens/user_service.dart.golden');
        expect(goldenFile.existsSync(), isTrue);
        final content = goldenFile.readAsStringSync();

        final tempDir = Directory.systemTemp.createTempSync('golden_test_');
        try {
          final libDir = Directory('${tempDir.path}/lib')..createSync();
          File('${libDir.path}/user_service.dart').writeAsStringSync(content);

          File('${libDir.path}/user.pb.dart').writeAsStringSync('''
class GetUserRequest { int get id => 0; }
class CreateUserRequest { String get name => ""; String get email => ""; Object toProto3Json() => {}; }
class User {}
''');

          File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: temp_golden
environment:
  sdk: '>=3.1.0 <4.0.0'
dependencies:
  protobuf: any
  dio: any
  protoc_gen_dart_unified:
    path: ${Directory.current.path}
''');

          final pubResult = await Process.run('dart', [
            'pub',
            'get',
          ], workingDirectory: tempDir.path);
          expect(
            pubResult.exitCode,
            0,
            reason: 'pub get failed: ${pubResult.stderr}',
          );

          final analyzeResult = await Process.run('dart', [
            'analyze',
            'lib/user_service.dart',
          ], workingDirectory: tempDir.path);
          expect(
            analyzeResult.exitCode,
            0,
            reason:
                'Analyzer failed: \n${analyzeResult.stdout}\n${analyzeResult.stderr}',
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Builds a FileDescriptorProto matching test/fixtures/user.proto
FileDescriptorProto _buildUserProtoFile() {
  return FileDescriptorProto()
    ..name = 'user.proto'
    ..package = 'user.v1'
    ..messageType.add(
      DescriptorProto()
        ..name = 'GetUserRequest'
        ..field.add(
          FieldDescriptorProto()
            ..name = 'id'
            ..number = 1
            ..type = FieldDescriptorProto_Type.TYPE_INT64
            ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
        ),
    )
    ..messageType.add(
      DescriptorProto()
        ..name = 'CreateUserRequest'
        ..field.add(
          FieldDescriptorProto()
            ..name = 'name'
            ..number = 1
            ..type = FieldDescriptorProto_Type.TYPE_STRING
            ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
        )
        ..field.add(
          FieldDescriptorProto()
            ..name = 'email'
            ..number = 2
            ..type = FieldDescriptorProto_Type.TYPE_STRING
            ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
        ),
    )
    ..messageType.add(
      DescriptorProto()
        ..name = 'User'
        ..field.add(
          FieldDescriptorProto()
            ..name = 'id'
            ..number = 1
            ..type = FieldDescriptorProto_Type.TYPE_INT64
            ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
        )
        ..field.add(
          FieldDescriptorProto()
            ..name = 'name'
            ..number = 2
            ..type = FieldDescriptorProto_Type.TYPE_STRING
            ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
        )
        ..field.add(
          FieldDescriptorProto()
            ..name = 'email'
            ..number = 3
            ..type = FieldDescriptorProto_Type.TYPE_STRING
            ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
        ),
    )
    ..service.add(
      ServiceDescriptorProto()
        ..name = 'UserService'
        ..method.add(
          MethodDescriptorProto()
            ..name = 'GetUser'
            ..inputType = '.user.v1.GetUserRequest'
            ..outputType = '.user.v1.User'
            ..options = _buildHttpOptions('get', '/v1/users/{id}'),
        )
        ..method.add(
          MethodDescriptorProto()
            ..name = 'CreateUser'
            ..inputType = '.user.v1.CreateUserRequest'
            ..outputType = '.user.v1.User'
            ..options = _buildHttpOptions('post', '/v1/users', body: '*'),
        ),
    );
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
  options.setExtension(Annotations.http, httpRuleMsg);
  return options;
}
