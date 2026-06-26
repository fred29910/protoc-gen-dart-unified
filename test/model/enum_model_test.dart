import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/model/enum_model.dart';
import 'package:protoc_gen_dart_unified/src/model/field_model.dart';
import 'package:protoc_gen_dart_unified/src/model/message_model.dart';

void main() {
  group('EnumModel', () {
    test('creates with name and values', () {
      final values = [
        const EnumValueModel(name: 'COLOR_RED', number: 0),
        const EnumValueModel(name: 'COLOR_GREEN', number: 1),
        const EnumValueModel(name: 'COLOR_BLUE', number: 2),
      ];
      final model = EnumModel(
        name: 'Color',
        fullName: '.v1.Color',
        values: values,
      );
      expect(model.name, equals('Color'));
      expect(model.fullName, equals('.v1.Color'));
      expect(model.values, hasLength(3));
    });

    test('EnumValueModel stores number and optional dartName', () {
      final value = EnumValueModel(
        name: 'ENUM_TYPE_UNSPECIFIED',
        number: 0,
        dartName: 'enumTypeUnspecified',
      );
      expect(value.name, equals('ENUM_TYPE_UNSPECIFIED'));
      expect(value.number, equals(0));
      expect(value.dartName, equals('enumTypeUnspecified'));
    });
  });

  group('FieldModel extended fields', () {
    test('new fields default to null/false when not specified', () {
      final field = FieldModel(
        name: 'test_field',
        type: 'TYPE_STRING',
      );
      expect(field.oneofName, isNull);
      expect(field.isEnum, isFalse);
      expect(field.enumValues, isNull);
      expect(field.mapKeyType, isNull);
      expect(field.mapValueType, isNull);
    });

    test('oneofName is set when provided', () {
      final field = FieldModel(
        name: 'user_type',
        type: 'TYPE_STRING',
        oneofName: 'user_info',
      );
      expect(field.oneofName, equals('user_info'));
    });

    test('isEnum and enumValues are set correctly', () {
      final field = FieldModel(
        name: 'color',
        type: 'TYPE_ENUM',
        isEnum: true,
        enumValues: ['COLOR_RED', 'COLOR_GREEN'],
      );
      expect(field.isEnum, isTrue);
      expect(field.enumValues, hasLength(2));
    });

    test('mapKeyType and mapValueType are set correctly', () {
      final field = FieldModel(
        name: 'tags',
        type: 'TYPE_MESSAGE',
        isMap: true,
        mapKeyType: 'TYPE_STRING',
        mapValueType: 'TYPE_INT32',
      );
      expect(field.isMap, isTrue);
      expect(field.mapKeyType, equals('TYPE_STRING'));
      expect(field.mapValueType, equals('TYPE_INT32'));
    });
  });

  group('MessageModel extended fields', () {
    test('enums defaults to empty list', () {
      final msg = MessageModel(
        name: 'Empty',
        fullName: '.v1.Empty',
        fields: [],
      );
      expect(msg.enums, isEmpty);
    });

    test('enums stores associated enum models', () {
      final enums = [
        EnumModel(
          name: 'Status',
          fullName: '.v1.Status',
          values: [
            const EnumValueModel(name: 'STATUS_OK', number: 0),
          ],
        ),
      ];
      final msg = MessageModel(
        name: 'Response',
        fullName: '.v1.Response',
        fields: [],
        enums: enums,
      );
      expect(msg.enums, hasLength(1));
      expect(msg.enums.first.name, equals('Status'));
    });
  });
}
