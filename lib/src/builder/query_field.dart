/// Represents a query parameter field.
class QueryField {
  final String name;
  final String dartAccessor;

  const QueryField({required this.name, required this.dartAccessor});

  @override
  bool operator ==(Object other) =>
      other is QueryField && name == other.name && dartAccessor == other.dartAccessor;

  @override
  int get hashCode => Object.hash(name, dartAccessor);
}
