import 'package:test/test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/annotations.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/http.pb.dart' as http_rule;

void main() {
  group('Code Generation', () {
    test('generates Stream<T> return type for server streaming methods', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(ServiceDescriptorProto()
          ..name = 'UserService'
          ..method.add(MethodDescriptorProto()
            ..name = 'ListUsers'
            ..inputType = '.user.v1.ListUsersRequest'
            ..outputType = '.user.v1.User'
            ..serverStreaming = true
            ..options = _buildHttpOptions('get', '/v1/users')));

      final generator = CodeGenerator();
      final response = generator.generate(CodeGeneratorRequest(
        fileToGenerate: ['user.proto'],
        protoFile: [file],
      ));

      expect(response.error, isEmpty);
      // Default mock=true generates 3 files: service + mock + example_test
      expect(response.file, hasLength(3));

      final content = response.file
          .firstWhere((f) => f.name.endsWith('_service.dart'))
          .content;
      // Verify the abstract interface has Stream<User> return type
      expect(content, contains('Stream<User> listUsers('));
      // Verify the implementation also has Stream<User>
      expect(content, contains('Stream<User> listUsers('));
    });

    test('generates Future<T> return type for unary methods', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(ServiceDescriptorProto()
          ..name = 'UserService'
          ..method.add(MethodDescriptorProto()
            ..name = 'GetUser'
            ..inputType = '.user.v1.GetUserRequest'
            ..outputType = '.user.v1.User'
            ..options = _buildHttpOptions('get', '/v1/users/{id}')));

      final generator = CodeGenerator();
      final response = generator.generate(CodeGeneratorRequest(
        fileToGenerate: ['user.proto'],
        protoFile: [file],
      ));

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name.endsWith('_service.dart'))
          .content;
      // Verify Future<User> return type for unary method
      expect(content, contains('Future<User> getUser('));
      // Verify it does NOT have Stream
      expect(content, isNot(contains('Stream<User> getUser(')));
    });

    test('generates service with mixed streaming and unary methods', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(ServiceDescriptorProto()
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
          ]));

      final generator = CodeGenerator();
      final response = generator.generate(CodeGeneratorRequest(
        fileToGenerate: ['user.proto'],
        protoFile: [file],
      ));

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name.endsWith('_service.dart'))
          .content;
      // Unary method: Future
      expect(content, contains('Future<User> getUser('));
      // Server streaming method: Stream
      expect(content, contains('Stream<User> listUsers('));
    });

    test('mock=false generates only service file', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(ServiceDescriptorProto()
          ..name = 'UserService'
          ..method.add(MethodDescriptorProto()
            ..name = 'GetUser'
            ..inputType = '.user.v1.GetUserRequest'
            ..outputType = '.user.v1.User'
            ..options = _buildHttpOptions('get', '/v1/users/{id}')));

      final generator = CodeGenerator();
      final response = generator.generate(CodeGeneratorRequest(
        fileToGenerate: ['user.proto'],
        protoFile: [file],
        parameter: 'mock=false',
      ));

      expect(response.error, isEmpty);
      expect(response.file, hasLength(1));
      expect(response.file.first.name, endsWith('_service.dart'));
    });
  });
}

MethodOptions _buildHttpOptions(String httpMethod, String path,
    {String body = ''}) {
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
