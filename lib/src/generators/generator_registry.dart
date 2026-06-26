import '../model/service_model.dart';
import 'service_generator.dart';
import 'mock_service_generator.dart';
import 'example_test_generator.dart';
import 'runtime_inline_generator.dart';

/// A registered generator entry that produces file output.
class GeneratorEntry {
  /// Human-readable name for debugging / error messages.
  final String name;

  /// Whether this generator runs per-service or once globally.
  final GeneratorScope scope;

  /// Generates file content for a service (only called when scope=perService).
  final String Function(ServiceModel service)? serviceGenerator;

  /// Generates file content once per request (only called when scope=global).
  final String Function()? globalGenerator;

  /// Returns the output file name for a given service name.
  /// For global generators, [serviceName] should be empty.
  final String Function(String serviceName) fileNameFn;

  const GeneratorEntry({
    required this.name,
    required this.scope,
    this.serviceGenerator,
    this.globalGenerator,
    required this.fileNameFn,
  });
}

/// Whether a generator runs per-service or once per entire request.
enum GeneratorScope { perService, global }

/// Registry that maps output file names to generators.
///
/// Replaces hardcoded dispatch in [CodeGenerator] with a pluggable registry.
/// Supports runtime enable/disable and easy extension with new generators.
class GeneratorRegistry {
  final List<GeneratorEntry> _entries = [];

  /// Creates an empty registry. Use [defaultRegistry] for the built-in setup.
  GeneratorRegistry();

  /// Registers a generator entry.
  void register(GeneratorEntry entry) {
    _entries.add(entry);
  }

  /// Returns all registered entries.
  List<GeneratorEntry> get entries => List.unmodifiable(_entries);

  /// Generates files for a given [service].
  /// [dartServiceName] is the snake_case Dart file name for the service.
  /// Returns a list of (fileName, content) pairs.
  List<(String, String)> generateForService(
    ServiceModel service,
    String dartServiceName,
  ) {
    final results = <(String, String)>[];
    for (final entry in _entries) {
      if (entry.scope == GeneratorScope.perService && entry.serviceGenerator != null) {
        results.add((
          entry.fileNameFn(dartServiceName),
          entry.serviceGenerator!(service),
        ));
      }
    }
    return results;
  }

  /// Generates global files (emitted once per request).
  List<(String, String)> generateGlobal() {
    final results = <(String, String)>[];
    for (final entry in _entries) {
      if (entry.scope == GeneratorScope.global && entry.globalGenerator != null) {
        results.add((
          entry.fileNameFn(''),
          entry.globalGenerator!(),
        ));
      }
    }
    return results;
  }

  /// Creates the default registry with built-in generators.
  factory GeneratorRegistry.defaultRegistry({
    bool mockEnabled = true,
  }) {
    final registry = GeneratorRegistry();

    registry.register(GeneratorEntry(
      name: 'Service',
      scope: GeneratorScope.perService,
      serviceGenerator: (service) => ServiceGenerator(service).generate(),
      fileNameFn: (name) => '$name.dart',
    ));

    if (mockEnabled) {
      registry.register(GeneratorEntry(
        name: 'Mock',
        scope: GeneratorScope.perService,
        serviceGenerator: (service) => MockServiceGenerator(service).generate(),
        fileNameFn: (name) => '${name}_mock.dart',
      ));

      registry.register(GeneratorEntry(
        name: 'ExampleTest',
        scope: GeneratorScope.perService,
        serviceGenerator: (service) =>
            ExampleTestGenerator(service).generate(),
        fileNameFn: (name) => '${name}_example_test.dart',
      ));
    }

    registry.register(GeneratorEntry(
      name: 'RuntimeInline',
      scope: GeneratorScope.global,
      globalGenerator: () => RuntimeInlineGenerator().generate(),
      fileNameFn: (_) => 'unified_runtime.dart',
    ));

    return registry;
  }
}
