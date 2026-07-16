import 'package:fixnum/fixnum.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:test/test.dart';

void main() {
  group('gRPC Transport Generation', () {
    test('generates gRPC adapter for gRPC-only service with mock=false', () {
      final file = FileDescriptorProto()
        ..name = 'auth.proto'
        ..package = 'auth.v1'
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'AuthService'
            ..method.addAll([
              MethodDescriptorProto()
                ..name = 'Login'
                ..inputType = '.auth.v1.LoginRequest'
                ..outputType = '.auth.v1.LoginResponse',
              MethodDescriptorProto()
                ..name = 'Register'
                ..inputType = '.auth.v1.RegisterRequest'
                ..outputType = '.auth.v1.RegisterResponse',
            ]),
        )
        ..messageType.addAll([
          // LoginRequest
          DescriptorProto()
            ..name = 'LoginRequest'
            ..field.addAll([
              FieldDescriptorProto()
                ..name = 'username'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
              FieldDescriptorProto()
                ..name = 'password'
                ..number = 2
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ]),
          // LoginResponse
          DescriptorProto()
            ..name = 'LoginResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'token'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
          // RegisterRequest
          DescriptorProto()
            ..name = 'RegisterRequest'
            ..field.addAll([
              FieldDescriptorProto()
                ..name = 'email'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
              FieldDescriptorProto()
                ..name = 'password'
                ..number = 2
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ]),
          // RegisterResponse
          DescriptorProto()
            ..name = 'RegisterResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'user_id'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        ]);

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(
          fileToGenerate: ['auth.proto'],
          protoFile: [file],
          parameter: 'mock=false',
        ),
      );

      expect(response.error, isEmpty);
      // Should generate 2 files: unified_runtime, auth_service (no mock/example)
      expect(response.file.length, equals(2));

      // Check the service file
      final serviceFile = response.file
          .firstWhere((f) => f.name == 'auth_service.dart');
      final content = serviceFile.content;

      // Should have _grpcClient field in UnifiedAuthService
      expect(content, contains('_grpcClient'));

      // Should call _grpcClient.unaryCall for gRPC methods
      expect(content, contains('_grpcClient!.unaryCall'));

      // Should import GrpcClient from unified_runtime
      expect(content, contains("import 'unified_runtime.dart'"));

      // ApiSdk should pass grpcClient to createTransport
      expect(content, contains('grpcClient:'));
    });

    test('generates gRPC adapter for gRPC-only service with mock=true', () {
      final file = FileDescriptorProto()
        ..name = 'auth.proto'
        ..package = 'auth.v1'
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'AuthService'
            ..method.addAll([
              MethodDescriptorProto()
                ..name = 'Login'
                ..inputType = '.auth.v1.LoginRequest'
                ..outputType = '.auth.v1.LoginResponse',
            ]),
        )
        ..messageType.addAll([
          DescriptorProto()
            ..name = 'LoginRequest'
            ..field.addAll([
              FieldDescriptorProto()
                ..name = 'username'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
              FieldDescriptorProto()
                ..name = 'password'
                ..number = 2
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ]),
          DescriptorProto()
            ..name = 'LoginResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'token'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        ]);

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(
          fileToGenerate: ['auth.proto'],
          protoFile: [file],
          parameter: 'mock=true',
        ),
      );

      expect(response.error, isEmpty);
      // Should generate 4 files: unified_runtime, auth_service, auth_service_mock, auth_service_example_test
      expect(response.file.length, equals(4));

      final serviceFile = response.file
          .firstWhere((f) => f.name == 'auth_service.dart');
      final content = serviceFile.content;

      // Should have _grpcClient field
      expect(content, contains('_grpcClient'));

      // Should call _grpcClient.unaryCall
      expect(content, contains('_grpcClient!.unaryCall'));
    });
  });
}
