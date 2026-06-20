/// Result of parsing an HTTP path template.
class PathMapping {
  final List<String> literalSegments;
  final List<String> pathFieldNames;

  const PathMapping({
    required this.literalSegments,
    required this.pathFieldNames,
  });

  @override
  bool operator ==(Object other) =>
      other is PathMapping &&
      _listEquals(literalSegments, other.literalSegments) &&
      _listEquals(pathFieldNames, other.pathFieldNames);

  @override
  int get hashCode => Object.hashAll([...literalSegments, ...pathFieldNames]);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
