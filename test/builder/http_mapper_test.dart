import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/builder/http_mapper.dart';
import 'package:protoc_gen_dart_unified/src/builder/path_mapping.dart';
import 'package:protoc_gen_dart_unified/src/builder/query_field.dart';
import 'package:protoc_gen_dart_unified/src/builder/body_mapping.dart';
import 'package:protoc_gen_dart_unified/src/model/field_model.dart';

void main() {
  group('HttpMapper.mapPath', () {
    test('parses simple path with single field', () {
      final fields = [FieldModel(name: 'id', type: 'int64')];
      final result = HttpMapper.mapPath('/v1/users/{id}', fields);
      expect(result.literalSegments, equals(['/v1/users/']));
      expect(result.pathFieldNames, equals(['id']));
    });

    test('parses path with multiple fields', () {
      final fields = [
        FieldModel(name: 'user_id', type: 'int64'),
        FieldModel(name: 'post_id', type: 'int64'),
      ];
      final result = HttpMapper.mapPath(
        '/v1/users/{user_id}/posts/{post_id}',
        fields,
      );
      expect(result.literalSegments, equals(['/v1/users/', '/posts/']));
      expect(result.pathFieldNames, equals(['user_id', 'post_id']));
    });

    test('parses path with segment wildcard', () {
      final fields = [FieldModel(name: 'name', type: 'string')];
      final result = HttpMapper.mapPath('/files/{name=segments/*}', fields);
      expect(result.literalSegments, equals(['/files/']));
      expect(result.pathFieldNames, equals(['name']));
    });

    test('parses path with no fields', () {
      final result = HttpMapper.mapPath('/v1/health', []);
      expect(result.literalSegments, equals(['/v1/health']));
      expect(result.pathFieldNames, isEmpty);
    });

    test('parses path with nested field reference', () {
      final fields = [FieldModel(name: 'user.id', type: 'string')];
      final result = HttpMapper.mapPath('/v1/users/{user.id}', fields);
      expect(result.literalSegments, equals(['/v1/users/']));
      expect(result.pathFieldNames, equals(['user.id']));
    });
  });

  group('HttpMapper.flattenQuery', () {
    test('returns non-path fields as query params', () {
      final fields = [
        FieldModel(name: 'id', type: 'int64'),
        FieldModel(name: 'page', type: 'int32'),
        FieldModel(name: 'limit', type: 'int32'),
      ];
      final result = HttpMapper.flattenQuery(fields, {'id'}, '');
      expect(result, hasLength(2));
      expect(result[0].name, equals('page'));
      expect(result[1].name, equals('limit'));
    });

    test('excludes body field from query params', () {
      final fields = [
        FieldModel(name: 'id', type: 'int64'),
        FieldModel(name: 'payload', type: 'string'),
      ];
      final result = HttpMapper.flattenQuery(fields, {'id'}, 'payload');
      expect(result, isEmpty);
    });

    test('returns empty when all fields consumed by path and body', () {
      final fields = [
        FieldModel(name: 'id', type: 'int64'),
        FieldModel(name: 'data', type: 'string'),
      ];
      final result = HttpMapper.flattenQuery(fields, {'id'}, 'data');
      expect(result, isEmpty);
    });

    test('returns all fields when no path or body', () {
      final fields = [
        FieldModel(name: 'page', type: 'int32'),
        FieldModel(name: 'limit', type: 'int32'),
      ];
      final result = HttpMapper.flattenQuery(fields, {}, '');
      expect(result, hasLength(2));
    });
  });

  group('HttpMapper.resolveBody', () {
    test('body: "*" maps to entire request', () {
      final fields = [
        FieldModel(name: 'name', type: 'string'),
        FieldModel(name: 'email', type: 'string'),
      ];
      final result = HttpMapper.resolveBody(fields, '*');
      expect(result.kind, equals('all'));
      expect(result.fieldName, isNull);
    });

    test('body: "field_name" maps to specific field', () {
      final fields = [
        FieldModel(name: 'name', type: 'string'),
        FieldModel(name: 'payload', type: 'string'),
      ];
      final result = HttpMapper.resolveBody(fields, 'payload');
      expect(result.kind, equals('field'));
      expect(result.fieldName, equals('payload'));
    });

    test('body: "" maps to no body', () {
      final fields = [FieldModel(name: 'id', type: 'int64')];
      final result = HttpMapper.resolveBody(fields, '');
      expect(result.kind, equals('none'));
      expect(result.fieldName, isNull);
    });
  });
}
