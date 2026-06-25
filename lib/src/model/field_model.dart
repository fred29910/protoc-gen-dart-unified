/// Represents a field in a protobuf message.
class FieldModel {
  final String name;
  final String type;
  final bool isRepeated;
  final bool isOptional;
  final bool isMap;
  final String? messageType;

  const FieldModel({
    required this.name,
    required this.type,
    this.isRepeated = false,
    this.isOptional = false,
    this.isMap = false,
    this.messageType,
  });
}
