import 'package:test/test.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/descriptor_parser.dart';

void main() {
  group('DescriptorParser oneof extraction', () {
    test('parses oneof fields with oneofName', () {
      final file = FileDescriptorProto()
        ..name = 'user.proto'
        ..package = 'user.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'User'
            ..field.addAll([
              FieldDescriptorProto()
                ..name = 'name'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
              FieldDescriptorProto()
                ..name = 'id_card'
                ..number = 2
                ..type = FieldDescriptorProto_Type.TYPE_STRING
                ..oneofIndex = 0, // first oneof
              FieldDescriptorProto()
                ..name = 'passport'
                ..number = 3
                ..type = FieldDescriptorProto_Type.TYPE_STRING
                ..oneofIndex = 0, // same oneof
              FieldDescriptorProto()
                ..name = 'avatar_url'
                ..number = 4
                ..type = FieldDescriptorProto_Type.TYPE_STRING
                ..oneofIndex = 1, // second oneof
            ])
            ..oneofDecl.addAll([
              OneofDescriptorProto()..name = 'identification',
              OneofDescriptorProto()..name = 'photo',
            ]),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final userMsg = services.first.messages.first;
      expect(userMsg.fields, hasLength(4));

      // name is not in any oneof
      expect(userMsg.fields[0].oneofName, isNull);

      // id_card and passport are in 'identification' oneof
      expect(userMsg.fields[1].oneofName, equals('identification'));
      expect(userMsg.fields[2].oneofName, equals('identification'));

      // avatar_url is in 'photo' oneof
      expect(userMsg.fields[3].oneofName, equals('photo'));
    });

    test('handles fields without oneof', () {
      final file = FileDescriptorProto()
        ..name = 'simple.proto'
        ..package = 'simple.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'Simple'
            ..field.addAll([
              FieldDescriptorProto()
                ..name = 'id'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_INT32,
              FieldDescriptorProto()
                ..name = 'name'
                ..number = 2
                ..type = FieldDescriptorProto_Type.TYPE_STRING,
            ]),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final simpleMsg = services.first.messages.first;
      expect(simpleMsg.fields, hasLength(2));
      expect(simpleMsg.fields[0].oneofName, isNull);
      expect(simpleMsg.fields[1].oneofName, isNull);
    });

    test('parses empty oneofDecl gracefully', () {
      final file = FileDescriptorProto()
        ..name = 'empty.proto'
        ..package = 'empty.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'Empty'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'id'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_INT32,
            ),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final emptyMsg = services.first.messages.first;
      expect(emptyMsg.fields, hasLength(1));
      expect(emptyMsg.fields[0].oneofName, isNull);
    });
  });

  group('DescriptorParser enum extraction', () {
    test('parses nested enum types into MessageModel.enums', () {
      final file = FileDescriptorProto()
        ..name = 'status.proto'
        ..package = 'status.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'Response'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'status'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_ENUM
                ..typeName = '.status.v1.Response.Status',
            )
            ..enumType.add(
              EnumDescriptorProto()
                ..name = 'Status'
                ..value.addAll([
                  EnumValueDescriptorProto()
                    ..name = 'STATUS_UNSPECIFIED'
                    ..number = 0,
                  EnumValueDescriptorProto()
                    ..name = 'STATUS_OK'
                    ..number = 1,
                  EnumValueDescriptorProto()
                    ..name = 'STATUS_ERROR'
                    ..number = 2,
                ]),
            ),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final responseMsg = services.first.messages.first;
      expect(responseMsg.enums, hasLength(1));

      final statusEnum = responseMsg.enums.first;
      expect(statusEnum.name, equals('Status'));
      expect(statusEnum.values, hasLength(3));
      expect(statusEnum.values[0].name, equals('STATUS_UNSPECIFIED'));
      expect(statusEnum.values[0].number, equals(0));
      expect(statusEnum.values[1].name, equals('STATUS_OK'));
      expect(statusEnum.values[1].number, equals(1));
    });

    test('parses enum fields with isEnum and enumValues', () {
      final file = FileDescriptorProto()
        ..name = 'status.proto'
        ..package = 'status.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'Response'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'status'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_ENUM
                ..typeName = '.status.v1.Response.Status',
            )
            ..enumType.add(
              EnumDescriptorProto()
                ..name = 'Status'
                ..value.addAll([
                  EnumValueDescriptorProto()
                    ..name = 'STATUS_UNSPECIFIED'
                    ..number = 0,
                  EnumValueDescriptorProto()
                    ..name = 'STATUS_OK'
                    ..number = 1,
                ]),
            ),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final statusField = services.first.messages.first.fields.first;
      expect(statusField.isEnum, isTrue);
      expect(statusField.enumValues, hasLength(2));
      expect(statusField.enumValues!.first, equals('STATUS_UNSPECIFIED'));
    });

    test('handles messages without enums', () {
      final file = FileDescriptorProto()
        ..name = 'simple.proto'
        ..package = 'simple.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'Simple'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'id'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_INT32,
            ),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final simpleMsg = services.first.messages.first;
      expect(simpleMsg.enums, isEmpty);
    });
  });

  group('DescriptorParser map field extraction', () {
    test('detects map fields with proper mapEntry option', () {
      final mapOptions = MessageOptions()..mapEntry = true;
      final entryMsg = DescriptorProto()
        ..name = 'TagsEntry'
        ..options = mapOptions
        ..field.addAll([
          FieldDescriptorProto()
            ..name = 'key'
            ..number = 1
            ..type = FieldDescriptorProto_Type.TYPE_STRING,
          FieldDescriptorProto()
            ..name = 'value'
            ..number = 2
            ..type = FieldDescriptorProto_Type.TYPE_INT32,
        ]);

      final file = FileDescriptorProto()
        ..name = 'map.proto'
        ..package = 'map.v1'
        ..messageType.addAll([
          entryMsg,
          DescriptorProto()
            ..name = 'Resource'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'tags'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_MESSAGE
                ..typeName = '.map.v1.TagsEntry'
                ..label = FieldDescriptorProto_Label.LABEL_REPEATED,
            ),
        ])
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      // DescriptorParser parses all messageTypes in order.
      // The Resource message is second (index 1).
      final resourceMsg = services.first.messages[1];
      final tagsField = resourceMsg.fields.firstWhere((f) => f.name == 'tags');
      expect(tagsField.isMap, isTrue);
      expect(tagsField.mapKeyType, isNotNull);
      expect(tagsField.mapKeyType, equals('TYPE_STRING'));
      expect(tagsField.mapValueType, isNotNull);
      expect(tagsField.mapValueType, equals('TYPE_INT32'));
    });

    test('mark non-map message field without mapKeyType/mapValueType', () {
      final file = FileDescriptorProto()
        ..name = 'simple.proto'
        ..package = 'simple.v1'
        ..messageType.add(
          DescriptorProto()
            ..name = 'Simple'
            ..field.add(
              FieldDescriptorProto()
                ..name = 'id'
                ..number = 1
                ..type = FieldDescriptorProto_Type.TYPE_INT32,
            ),
        )
        ..service.add(ServiceDescriptorProto()..name = 'DummyService');

      final parser = DescriptorParser();
      final services = parser.parse([file]);

      final simpleMsg = services.first.messages.first;
      final idField = simpleMsg.fields.first;
      expect(idField.isMap, isFalse);
      expect(idField.mapKeyType, isNull);
      expect(idField.mapValueType, isNull);
    });
  });
}
