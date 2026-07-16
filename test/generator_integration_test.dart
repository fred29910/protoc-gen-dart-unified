import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/annotations.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/http.pb.dart'
    as http_rule;

void main() {
  group('Code Generation', () {
    test('generates Stream<T> return type for server streaming methods', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'UserService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'ListUsers'
                ..inputType = '.user.v1.ListUsersRequest'
                ..outputType = '.user.v1.User'
                ..serverStreaming = true
                ..options = _buildHttpOptions('get', '/v1/users'),
            ),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['user.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      // Default mock=true generates 4 files: unified_runtime + service + mock + example_test
      expect(response.file, hasLength(4));

      final content = response.file
          .firstWhere((f) => f.name == 'user_service.dart')
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
        CodeGeneratorRequest(fileToGenerate: ['user.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name == 'user_service.dart')
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
        CodeGeneratorRequest(fileToGenerate: ['user.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name == 'user_service.dart')
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

      expect(response.error, isEmpty);
      expect(response.file, hasLength(2));
      expect(response.file[0].name, equals('unified_runtime.dart'));
      expect(response.file[1].name, equals('user_service.dart'));
    });

    test('gRPC-only service has no pbgrpc import in directives', () {
      // echo.proto fixture: pure gRPC service, no google.api.http annotations
      final file = FileDescriptorProto()
        ..name = 'echo.proto'
        ..package = 'echo'
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoRequest'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'EchoService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'Echo'
                ..inputType = '.echo.EchoRequest'
                ..outputType = '.echo.EchoResponse',
            ),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['echo.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name == 'echo_service.dart')
          .content;

      // gRPC-only services must NOT import pbgrpc (web isolation)
      expect(content, isNot(contains("import '../echo.pbgrpc.dart'")),
          reason: 'gRPC-only services should not import pbgrpc');
      // Only unified_runtime.dart + *.pb.dart imports remain
      expect(content, contains("import 'unified_runtime.dart'"));
      expect(content, contains("import 'echo.pb.dart'"));
    });

    test('Unified<Service> for gRPC has no _grpcClient field or grpcClient ctor param', () {
      // echo.proto fixture: pure gRPC service, no google.api.http annotations.
      // After web-grpc-isolation, Unified must hold only _transport + _interceptors
      // and delegate via _transport (Task 1.3/1.4), never a _grpcClient field.
      final file = FileDescriptorProto()
        ..name = 'echo.proto'
        ..package = 'echo'
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoRequest'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'EchoService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'Echo'
                ..inputType = '.echo.EchoRequest'
                ..outputType = '.echo.EchoResponse',
            ),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['echo.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name == 'echo_service.dart')
          .content;

      // Unified class must NOT declare a _grpcClient field
      expect(content, isNot(contains('final GrpcClient _grpcClient')),
          reason: 'Unified class should not declare a _grpcClient field');
      // Unified constructor must NOT take a grpcClient parameter
      expect(content, isNot(contains('this.grpcClient')),
          reason: 'Unified constructor should not take a grpcClient parameter');
      // Only _transport and _interceptors fields remain
      expect(content, contains('final Transport _transport'));
      expect(content, contains('final List<RpcInterceptor> _interceptors'));
    });

    test('gRPC unary call delegates to _transport.unaryCall', () {
      // echo.proto fixture: pure gRPC service, no google.api.http annotations.
      // After web-grpc-isolation, the unary call body must route through
      // _transport.unaryCall (carrying ctx.options), not _grpcClient.unaryCall.
      final file = FileDescriptorProto()
        ..name = 'echo.proto'
        ..package = 'echo'
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoRequest'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'EchoService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'Echo'
                ..inputType = '.echo.EchoRequest'
                ..outputType = '.echo.EchoResponse',
            ),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['echo.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name == 'echo_service.dart')
          .content;

      // The echo method must exist
      expect(content, contains('Future<EchoResponse> echo('),
          reason: 'echo method should exist');
      // The unary call body must delegate to _transport.unaryCall
      expect(content, contains('_transport.unaryCall<EchoResponse>'),
          reason: 'method should delegate to _transport.unaryCall');
      // It must NOT call _grpcClient.unaryCall directly
      expect(content, isNot(contains('_grpcClient.unaryCall')),
          reason: 'should not call _grpcClient directly');
    });

    test('gRPC server stream call delegates to _transport.serverStream', () {
      // echo.proto fixture: pure gRPC service, no google.api.http annotations.
      // After web-grpc-isolation, the server streaming call body must route
      // through _transport.serverStream, not _grpcClient.serverStream.
      final file = FileDescriptorProto()
        ..name = 'echo.proto'
        ..package = 'echo'
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoRequest'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..messageType.add(
          DescriptorProto()
            ..name = 'EchoResponse'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'message'
                ..number = 1
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ),
        )
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'EchoService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'EchoStream'
                ..inputType = '.echo.EchoRequest'
                ..outputType = '.echo.EchoResponse'
                ..serverStreaming = true,
            ),
        );

      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: ['echo.proto'], protoFile: [file]),
      );

      expect(response.error, isEmpty);
      final content = response.file
          .firstWhere((f) => f.name == 'echo_service.dart')
          .content;

      // The echoStream method must exist
      expect(content, contains('Stream<EchoResponse> echoStream('),
          reason: 'echoStream method should exist');
      // The server stream call body must delegate to _transport.serverStream
      expect(content, contains('_transport.serverStream<EchoResponse>'),
          reason: 'method should delegate to _transport.serverStream');
      // It must NOT call _grpcClient.serverStream directly
      expect(content, isNot(contains('_grpcClient.serverStream')),
          reason: 'should not call _grpcClient directly');
    });

    test('declares FEATURE_PROTO3_OPTIONAL in supportedFeatures', () {
      final generator = CodeGenerator();
      final response = generator.generate(
        CodeGeneratorRequest(fileToGenerate: [], protoFile: []),
      );

      expect(response.hasSupportedFeatures(), isTrue);
      // FEATURE_PROTO3_OPTIONAL = 1
      expect(response.supportedFeatures, equals(Int64(1)));
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
  options.setExtension(Annotations.http, httpRuleMsg);
  return options;
}
