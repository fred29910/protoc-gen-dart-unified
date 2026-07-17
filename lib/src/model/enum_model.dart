/// Represents a protobuf enum type definition.
class EnumModel {
  final String name;
  final String fullName;
  final List<EnumValueModel> values;

  const EnumModel({
    required this.name,
    required this.fullName,
    required this.values,
  });
}

/// Represents a single value in a protobuf enum.
class EnumValueModel {
  final String name;
  final int number;
  final String? dartName;

  const EnumValueModel({
    required this.name,
    required this.number,
    this.dartName,
  });
}
