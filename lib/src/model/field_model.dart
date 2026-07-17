/// Represents a field in a protobuf message.
class FieldModel {
  final String name;
  final String type;
  final bool isRepeated;
  final bool isOptional;
  final bool isMap;
  final String? messageType;

  /// The oneof group name if this field belongs to a oneof.
  final String? oneofName;

  /// Whether this field is a protobuf enum type.
  final bool isEnum;

  /// The enum value names if this field is an enum type.
  final List<String>? enumValues;

  /// The map key type (e.g. TYPE_STRING) if this field is a map.
  final String? mapKeyType;

  /// The map value type (e.g. TYPE_INT32) if this field is a map.
  final String? mapValueType;

  const FieldModel({
    required this.name,
    required this.type,
    this.isRepeated = false,
    this.isOptional = false,
    this.isMap = false,
    this.messageType,
    this.oneofName,
    this.isEnum = false,
    this.enumValues,
    this.mapKeyType,
    this.mapValueType,
  });
}
