import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import '../model/service_model.dart';

/// Generates a mock client file (*_mock.dart) for testing purposes.
///
/// Produces a `Mock` class that implements the abstract service interface,
/// ready for use with mockito (no build_runner needed).
class MockServiceGenerator {
  final ServiceModel service;

  MockServiceGenerator(this.service);

  /// Generates the complete mock file content.
  String generate() {
    final library = Library(
      (b) => b
        ..directives.addAll(_buildDirectives())
        ..body.add(_buildMockClass()),
    );

    final emitter = DartEmitter.scoped();
    final source = library.accept(emitter).toString();
    final formatter = DartFormatter(languageVersion: Version(3, 10, 0));
    return formatter.format('// ignore_for_file: type=lint\n$source');
  }

  List<Directive> _buildDirectives() {
    return [
      Directive.import('package:mockito/mockito.dart'),
      Directive.import(
        service.protoFileName.replaceAll('.proto', '.pb.dart'),
      ),
      Directive.import('${_dartServiceName(service.name)}.dart'),
    ];
  }

  /// Builds the mock class that extends [Mock] and implements the service.
  Class _buildMockClass() {
    final mockClassName = 'Mock${service.name}';

    return Class(
      (b) => b
        ..name = mockClassName
        ..extend = refer('Mock')
        ..implements.add(refer(service.name)),
    );
  }

  /// Converts proto service name to Dart file name (PascalCase → snake_case).
  String _dartServiceName(String protoName) {
    return protoName
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst('_', '');
  }
}
