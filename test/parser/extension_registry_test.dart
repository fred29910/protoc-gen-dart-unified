import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/parser/extension_registry.dart';

void main() {
  group('ExtensionRegistry', () {
    test('createHttpExtensionRegistry returns valid registry', () {
      final registry = createHttpExtensionRegistry();
      expect(registry, isNotNull);
    });

    test('google.api.http not silently lost (placeholder)', () {
      // TODO(Task 3.2): Replace with actual annotation extraction test
      // This test exists to ensure we don't forget custom option handling
      final registry = createHttpExtensionRegistry();
      expect(registry, isNotNull);
    });
  });
}
