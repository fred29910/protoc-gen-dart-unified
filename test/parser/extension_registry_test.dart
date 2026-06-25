import 'package:test/test.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/extension_registry.dart';
import 'package:protoc_gen_dart_unified/src/parser/descriptor_parser.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/annotations.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/google/api/http.pb.dart'
    as http_rule;

void main() {
  group('ExtensionRegistry', () {
    test(
      'createHttpExtensionRegistry returns registry with http extension',
      () {
        final registry = createHttpExtensionRegistry();
        expect(registry, isNotNull);
      },
    );
  });

  group('DescriptorParser google.api.http extraction', () {
    test(
      'extracts HttpRule from method with google.api.http get annotation',
      () {
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

        final parser = DescriptorParser();
        final services = parser.parse([file]);

        expect(services, hasLength(1));
        expect(services.first.methods, hasLength(1));

        final method = services.first.methods.first;
        expect(
          method.httpRule,
          isNotNull,
          reason: 'google.api.http annotation should not be silently lost',
        );
        expect(method.httpRule!.kind, equals('get'));
        expect(method.httpRule!.path, equals('/v1/users/{id}'));
      },
    );

    test(
      'extracts HttpRule from method with google.api.http post annotation',
      () {
        final file = FileDescriptorProto()
          ..name = 'user.proto'
          ..package = 'user.v1'
          ..service.add(
            ServiceDescriptorProto()
              ..name = 'UserService'
              ..method.add(
                MethodDescriptorProto()
                  ..name = 'CreateUser'
                  ..inputType = '.user.v1.CreateUserRequest'
                  ..outputType = '.user.v1.User'
                  ..options = _buildHttpOptions('post', '/v1/users', body: '*'),
              ),
          );

        final parser = DescriptorParser();
        final services = parser.parse([file]);

        final method = services.first.methods.first;
        expect(method.httpRule, isNotNull);
        expect(method.httpRule!.kind, equals('post'));
        expect(method.httpRule!.path, equals('/v1/users'));
        expect(method.httpRule!.body, equals('*'));
      },
    );

    test('returns null HttpRule for method without annotation', () {
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
                ..outputType = '.user.v1.User',
            ),
        );

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final method = services.first.methods.first;
      expect(method.httpRule, isNull);
    });

    test('detects server streaming from method descriptor', () {
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
                ..serverStreaming = true,
            ),
        );

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final method = services.first.methods.first;
      expect(method.isServerStreaming, isTrue);
      expect(method.isClientStreaming, isFalse);
    });

    test('parses LABEL_OPTIONAL fields with isOptional flag', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..syntax = 'proto3'
        ..messageType.add(
          DescriptorProto()
            ..name = 'GetUserRequest'
            ..field.addAll([
              // Optional field (LABEL_OPTIONAL)
              FieldDescriptorProto()
                ..name = 'id'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
              // Regular proto3 field (LABEL_OPTIONAL is also default in proto2,
              // but for proto3 without explicit 'optional' keyword, labels are
              // LABEL_OPTIONAL too — the distinction is proto3_optional flag)
              FieldDescriptorProto()
                ..name = 'name'
                ..number = 2
                ..type = FieldDescriptorProto_Type.TYPE_STRING
                ..label = FieldDescriptorProto_Label.LABEL_OPTIONAL,
              // Repeated field
              FieldDescriptorProto()
                ..name = 'tags'
                ..number = 3
                ..type = FieldDescriptorProto_Type.TYPE_STRING
                ..label = FieldDescriptorProto_Label.LABEL_REPEATED,
            ]),
        )
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'UserService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'GetUser'
                ..inputType = '.user.v1.GetUserRequest'
                ..outputType = '.user.v1.User',
            ),
        );

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      expect(services, hasLength(1));
      expect(services.first.messages, hasLength(1));

      final message = services.first.messages.first;
      expect(message.fields, hasLength(3));

      // Optional field
      final idField = message.fields[0];
      expect(idField.name, equals('id'));
      expect(idField.isOptional, isTrue);
      expect(idField.isRepeated, isFalse);

      // Regular proto3 field (without explicit optional)
      final nameField = message.fields[1];
      expect(nameField.name, equals('name'));
      expect(nameField.isOptional, isTrue);
      expect(nameField.isRepeated, isFalse);

      // Repeated field
      final tagsField = message.fields[2];
      expect(tagsField.name, equals('tags'));
      expect(tagsField.isOptional, isFalse);
      expect(tagsField.isRepeated, isTrue);
    });

    test('detects client streaming from method descriptor', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..service.add(
          ServiceDescriptorProto()
            ..name = 'UserService'
            ..method.add(
              MethodDescriptorProto()
                ..name = 'UploadUsers'
                ..inputType = '.user.v1.UploadRequest'
                ..outputType = '.user.v1.UploadResponse'
                ..clientStreaming = true,
            ),
        );

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final method = services.first.methods.first;
      expect(method.isClientStreaming, isTrue);
      expect(method.isServerStreaming, isFalse);
    });
  });
}

/// Helper to build MethodOptions with google.api.http annotation.
/// Creates a HttpRule message and sets it as extension field 72295728.
MethodOptions _buildHttpOptions(
  String httpMethod,
  String path, {
  String body = '',
}) {
  // Build HttpRule with the specified pattern
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

  // Build MethodOptions and set the http extension
  final options = MethodOptions();
  options.setExtension(Annotations.http, httpRuleMsg);
  return options;
}
