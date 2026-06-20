import 'package:protobuf/protobuf.dart';

/// Creates an ExtensionRegistry pre-registered with google.api.http extensions.
///
/// The google.api.http extension (field 72295728 on MethodOptions) requires
/// the generated descriptor classes from googleapis/googleapis.
/// This function returns an empty registry placeholder; actual registration
/// requires the vendored google/api/annotations.pb.dart at build time.
///
/// See: https://github.com/google/googleapis/blob/master/google/api/annotations.proto
/// Extension field number: 72295728
ExtensionRegistry createHttpExtensionRegistry() {
  final registry = ExtensionRegistry();
  // TODO: When annotations.pb.dart is available:
  // registry.add(Annotations.http);
  // For now, return empty registry as placeholder
  return registry;
}
