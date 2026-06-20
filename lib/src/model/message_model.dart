import 'field_model.dart';

/// Represents a protobuf message with its fields.
class MessageModel {
  final String name;
  final String fullName;
  final List<FieldModel> fields;

  const MessageModel({
    required this.name,
    required this.fullName,
    required this.fields,
  });
}
