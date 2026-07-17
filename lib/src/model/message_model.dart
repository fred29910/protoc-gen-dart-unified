import 'enum_model.dart';
import 'field_model.dart';

/// Represents a protobuf message with its fields and nested enums.
class MessageModel {
  final String name;
  final String fullName;
  final List<FieldModel> fields;

  /// Enum types defined within this message.
  final List<EnumModel> enums;

  const MessageModel({
    required this.name,
    required this.fullName,
    required this.fields,
    this.enums = const [],
  });
}
