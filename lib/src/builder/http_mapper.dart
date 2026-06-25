import '../model/field_model.dart';
import 'path_mapping.dart';
import 'query_field.dart';
import 'body_mapping.dart';

/// HTTP mapping engine that translates HttpRule path templates, query
/// parameters, and body mappings into Dart code generation inputs.
class HttpMapper {
  /// Parses an HTTP path template into literal segments and field names.
  ///
  /// Supports `{field}` and `{field=segments/*}` patterns.
  /// Uses a state-machine parser (not regex) for correctness.
  ///
  /// Example:
  ///   `/v1/users/{id}/posts/{post_id=posts/*}`
  ///   → PathMapping(
  ///       literalSegments: ['/v1/users/', '/posts/'],
  ///       pathFieldNames: ['id', 'post_id'],
  ///     )
  static PathMapping mapPath(String template, List<FieldModel> fields) {
    final literalSegments = <String>[];
    final pathFieldNames = <String>[];
    final currentLiteral = StringBuffer();
    final currentField = StringBuffer();
    var inBrace = false;

    for (var i = 0; i < template.length; i++) {
      final ch = template[i];
      if (ch == '{') {
        if (inBrace) {
          // Nested brace — treat as literal
          currentLiteral.write(ch);
          currentField.write(ch);
        } else {
          inBrace = true;
          literalSegments.add(currentLiteral.toString());
          currentLiteral.clear();
          currentField.clear();
        }
      } else if (ch == '}') {
        if (inBrace) {
          inBrace = false;
          var fieldName = currentField.toString();
          // Handle {field=segments/*} pattern — extract just the field name
          final eqIndex = fieldName.indexOf('=');
          if (eqIndex >= 0) {
            fieldName = fieldName.substring(0, eqIndex);
          }
          pathFieldNames.add(fieldName);
          currentField.clear();
        } else {
          currentLiteral.write(ch);
        }
      } else {
        if (inBrace) {
          currentField.write(ch);
        } else {
          currentLiteral.write(ch);
        }
      }
    }

    // Add trailing literal
    if (currentLiteral.isNotEmpty || literalSegments.isEmpty) {
      literalSegments.add(currentLiteral.toString());
    }

    return PathMapping(
      literalSegments: literalSegments,
      pathFieldNames: pathFieldNames,
    );
  }

  /// Determines which fields become query parameters.
  ///
  /// Excludes fields that are:
  /// - Used in the path template (pathFields)
  /// - Used as the body (bodyField, if non-empty)
  static List<QueryField> flattenQuery(
    List<FieldModel> fields,
    Set<String> pathFields,
    String bodyField,
  ) {
    final queryFields = <QueryField>[];
    for (final field in fields) {
      if (pathFields.contains(field.name)) continue;
      if (bodyField.isNotEmpty && field.name == bodyField) continue;
      queryFields.add(QueryField(name: field.name, dartAccessor: field.name));
    }
    return queryFields;
  }

  /// Resolves the body mapping from an HttpRule body field.
  ///
  /// Returns:
  /// - `BodyMapping(kind: 'all')` when body is `"*"`
  /// - `BodyMapping(kind: 'field', fieldName: name)` when body is a field name
  /// - `BodyMapping(kind: 'none')` when body is empty
  static BodyMapping resolveBody(List<FieldModel> fields, String body) {
    if (body == '*') {
      return const BodyMapping(kind: 'all');
    } else if (body.isNotEmpty) {
      return BodyMapping(kind: 'field', fieldName: body);
    } else {
      return const BodyMapping(kind: 'none');
    }
  }
}
