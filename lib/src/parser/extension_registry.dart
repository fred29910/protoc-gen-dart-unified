import 'package:protobuf/protobuf.dart';
import 'google/api/annotations.pb.dart';

/// Creates an ExtensionRegistry pre-registered with google.api.http extensions.
///
/// The google.api.http extension (field 72295728 on MethodOptions) is defined
/// in google/api/annotations.proto and allows reading HTTP bindings from
/// proto method options.
///
/// See: https://github.com/google/googleapis/blob/master/google/api/annotations.proto
/// Extension field number: 72295728
ExtensionRegistry createHttpExtensionRegistry() {
  final registry = ExtensionRegistry();
  registry.add(Annotations.http);
  return registry;
}
