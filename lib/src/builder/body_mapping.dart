/// Result of resolving the body field from an HttpRule.
class BodyMapping {
  final String kind; // "all", "field", "none"
  final String? fieldName;

  const BodyMapping({required this.kind, this.fieldName});

  @override
  bool operator ==(Object other) =>
      other is BodyMapping &&
      kind == other.kind &&
      fieldName == other.fieldName;

  @override
  int get hashCode => Object.hash(kind, fieldName);
}
