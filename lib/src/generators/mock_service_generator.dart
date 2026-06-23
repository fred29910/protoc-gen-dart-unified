import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';

/// Generates a mock client file (*_mock.dart) for testing purposes.
///
/// Produces a `@GenerateNiceMocks` annotated class that implements
/// the abstract service interface, ready for use with mockito + build_runner.
class MockServiceGenerator {
  final ServiceModel service;

  MockServiceGenerator(this.service);

  /// Generates the complete mock file content.
  String generate() {
    final library = Library((b) => b
      ..directives.addAll(_buildDirectives())
      ..body.add(_buildMockClass()));

    final emitter = DartEmitter.scoped();
    final source = library.accept(emitter).toString();
    final formatter = DartFormatter(languageVersion: Version(3, 10, 0));
    return formatter.format('// ignore_for_file: type=lint\n$source');
  }

  List<Directive> _buildDirectives() {
    return [
      Directive.import('package:mockito/annotations.dart'),
      Directive.import('../${service.protoFileName.replaceAll('.proto', '.pb.dart')}'),
      Directive.import('${_dartServiceName(service.name)}_service.dart'),
    ];
  }

  /// Builds the mock class with @GenerateNiceMocks annotation.
  Class _buildMockClass() {
    final mockClassName = 'Mock${service.name}';

    return Class((b) => b
      ..name = mockClassName
      ..annotations.add(refer('GenerateNiceMocks').call([
        literalList([refer(mockClassName)])
      ]))
      ..implements.add(refer(service.name))
      ..methods.addAll(service.methods.map(_buildMockMethod)));
  }

  /// Builds a single mock method that throws UnimplementedError.
  Method _buildMockMethod(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    final returnType = method.isServerStreaming
        ? refer('Stream<${method.outputType}>')
        : refer('Future<${method.outputType}>');

    return Method((b) => b
      ..name = methodName
      ..annotations.add(refer('override'))
      ..returns = returnType
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'request'
        ..type = refer(method.inputType)))
      ..body = const Code('throw UnimplementedError();'));
  }

  /// Converts proto service name to Dart file name (PascalCase → snake_case).
  String _dartServiceName(String protoName) {
    return protoName.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst('_', '');
  }

  /// Converts proto method name to Dart method name (PascalCase → camelCase).
  String _dartMethodName(String protoName) {
    if (protoName.isEmpty) return protoName;
    return protoName[0].toLowerCase() + protoName.substring(1);
  }
}
