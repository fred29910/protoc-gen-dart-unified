import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/generators/generator_registry.dart';
import 'package:protoc_gen_dart_unified/src/model/service_model.dart';
import 'package:protoc_gen_dart_unified/src/model/method_model.dart';

void main() {
  group('GeneratorRegistry', () {
    late ServiceModel testService;

    setUp(() {
      testService = ServiceModel(
        name: 'TestService',
        protoFileName: 'test.proto',
        methods: [
          MethodModel(
            name: 'TestMethod',
            inputType: 'TestRequest',
            outputType: 'TestResponse',
            httpRule: null,
            isServerStreaming: false,
            isClientStreaming: false,
          ),
        ],
        messages: [],
      );
    });

    test('empty registry produces no output', () {
      final registry = GeneratorRegistry();
      final perService = registry.generateForService(testService, 'test_service');
      final global = registry.generateGlobal();
      expect(perService, isEmpty);
      expect(global, isEmpty);
    });

    test('defaultRegistry with mockEnabled=true produces 4 entries', () {
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: true);
      expect(registry.entries, hasLength(4));
    });

    test('defaultRegistry with mockEnabled=false produces 2 entries', () {
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: false);
      expect(registry.entries, hasLength(2));
    });

    test('per-service generator produces expected file name', () {
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: true);
      final results = registry.generateForService(testService, 'test_service');
      final fileNames = results.map((r) => r.$1).toList();
      expect(fileNames, contains('test_service.dart'));
      expect(fileNames, contains('test_service_mock.dart'));
      expect(fileNames, contains('test_service_example_test.dart'));
    });

    test('per-service generator produces non-empty content', () {
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: true);
      final results = registry.generateForService(testService, 'test_service');
      for (final (_, content) in results) {
        expect(content, isNotEmpty);
      }
    });

    test('global generator produces unified_runtime.dart', () {
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: false);
      final results = registry.generateGlobal();
      expect(results, hasLength(1));
      expect(results.first.$1, equals('unified_runtime.dart'));
      expect(results.first.$2, isNotEmpty);
    });

    test('mockEnabled=false excludes mock and example_test generators', () {
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: false);
      final results = registry.generateForService(testService, 'test_service');
      final fileNames = results.map((r) => r.$1).toList();
      expect(fileNames, hasLength(1));
      expect(fileNames.first, equals('test_service.dart'));
    });

    test('supports custom generator registration', () {
      final registry = GeneratorRegistry();
      registry.register(GeneratorEntry(
        name: 'Custom',
        scope: GeneratorScope.global,
        globalGenerator: () => 'custom content',
        fileNameFn: (_) => 'custom.txt',
      ));
      final results = registry.generateGlobal();
      expect(results, hasLength(1));
      expect(results.first.$1, equals('custom.txt'));
      expect(results.first.$2, equals('custom content'));
    });

    test('entries getter returns unmodifiable list', () {
      final registry = GeneratorRegistry();
      expect(() => registry.entries.add(
        GeneratorEntry(
          name: 'ShouldFail',
          scope: GeneratorScope.global,
          globalGenerator: () => '',
          fileNameFn: (_) => 'fail.txt',
        ),
      ), throwsUnsupportedError);
    });
  });
}
