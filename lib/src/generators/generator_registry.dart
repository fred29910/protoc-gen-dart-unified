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

  /// Whether this entry is enabled. Disabled entries are skipped during
  /// generation but remain in the registry.
  bool enabled;

  /// Generates file content for a service (only called when scope=perService).
  final String Function(ServiceModel service)? serviceGenerator;

  /// Generates file content once per request (only called when scope=global).
  final String Function()? globalGenerator;

  /// Returns the output file name for a given service name.
  /// For global generators, [serviceName] should be empty.
  final String Function(String serviceName) fileNameFn;

  GeneratorEntry({
    required this.name,
    required this.scope,
    this.serviceGenerator,
    this.globalGenerator,
    required this.fileNameFn,
    this.enabled = true,
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

  /// Finds an entry by [name] and sets its [enabled] state.
  /// Returns true if an entry was found and updated.
  bool setEnabled(String name, bool enabled) {
    for (final entry in _entries) {
      if (entry.name == name) {
        entry.enabled = enabled;
        return true;
      }
    }
    return false;
  }

  /// Returns entries filtered by the current enabled state.
  List<GeneratorEntry> enabledEntries() =>
      _entries.where((e) => e.enabled).toList();

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
      if (entry.enabled && entry.scope == GeneratorScope.perService && entry.serviceGenerator != null) {
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
      if (entry.enabled && entry.scope == GeneratorScope.global && entry.globalGenerator != null) {
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

    // Approach A1 (web/gRPC isolation): the runtime is split into a
    // platform-agnostic `unified_runtime.dart` plus a conditional-import
    // transport factory set. Each file is emitted by its own global generator.
    registry.register(GeneratorEntry(
      name: 'TransportFactory',
      scope: GeneratorScope.global,
      globalGenerator: () => RuntimeInlineGenerator().generateTransportFactory(),
      fileNameFn: (_) => 'unified_transport_factory.dart',
    ));

    registry.register(GeneratorEntry(
      name: 'TransportNative',
      scope: GeneratorScope.global,
      globalGenerator: () => RuntimeInlineGenerator().generateTransportNative(),
      fileNameFn: (_) => 'unified_transport_native.dart',
    ));

    registry.register(GeneratorEntry(
      name: 'TransportWeb',
      scope: GeneratorScope.global,
      globalGenerator: () => RuntimeInlineGenerator().generateTransportWeb(),
      fileNameFn: (_) => 'unified_transport_web.dart',
    ));

    registry.register(GeneratorEntry(
      name: 'TransportStub',
      scope: GeneratorScope.global,
      globalGenerator: () => RuntimeInlineGenerator().generateTransportStub(),
      fileNameFn: (_) => 'unified_transport_stub.dart',
    ));

    return registry;
  }
}
