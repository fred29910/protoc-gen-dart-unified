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
      // Should generate 7 files: 5 runtime files + auth_service + adapter (no mock/example)
      expect(response.file.length, equals(7));

      // Check the service file
      final serviceFile = response.file
          .firstWhere((f) => f.name == 'auth_service.dart');
      final content = serviceFile.content;

      // UnifiedAuthService must NOT hold a _grpcClient field (web-grpc-isolation)
      expect(content, isNot(contains('_grpcClient')));

      // gRPC unary methods must route through _transport.unaryCall
      expect(content, contains('_transport.unaryCall'));

      // Should NOT call _grpcClient.unaryCall directly
      expect(content, isNot(contains('_grpcClient!.unaryCall')));

      // Should import GrpcClient from unified_runtime
      expect(content, contains("import 'unified_runtime.dart'"));

      // ApiSdk should pass grpcClient to createTransport (web-grpc-isolation, fixed in 1.5)
      expect(content, contains('createTransport('));
      expect(content, contains('grpcClient: grpcClient'));
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
      // Should generate 9 files: 5 runtime files + auth_service + mock + example_test + adapter
      expect(response.file.length, equals(9));

      final serviceFile = response.file
          .firstWhere((f) => f.name == 'auth_service.dart');
      final content = serviceFile.content;

      // Should NOT have _grpcClient field
      expect(content, isNot(contains('_grpcClient')));

      // gRPC unary methods must route through _transport.unaryCall
      expect(content, contains('_transport.unaryCall'));

      // Should NOT call _grpcClient.unaryCall directly
      expect(content, isNot(contains('_grpcClient!.unaryCall')));
    });
  });
}
