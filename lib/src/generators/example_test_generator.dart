import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';

/// Generates an example test file (*_example_test.dart) for testing purposes.
///
/// Produces a test file with group/test structure and commented stub templates
/// for each service method, ready for use with mockito.
class ExampleTestGenerator {
  final ServiceModel service;

  ExampleTestGenerator(this.service);

  /// Generates the complete example test file content.
  String generate() {
    final library = Library(
      (b) => b
        ..directives.addAll(_buildDirectives())
        ..body.add(_buildMainFunction()),
    );

    final emitter = DartEmitter.scoped();
    final source = library.accept(emitter).toString();
    final formatter = DartFormatter(languageVersion: Version(3, 10, 0));
    return formatter.format('// ignore_for_file: type=lint\n$source');
  }

  List<Directive> _buildDirectives() {
    final serviceName = _dartServiceName(service.name);
    return [
      Directive.import('unified_runtime.dart'),
      Directive.import('package:test/test.dart'),
      Directive.import('package:mockito/mockito.dart'),
      Directive.import(
        '../${service.protoFileName.replaceAll('.proto', '.pb.dart')}',
      ),
      Directive.import('${serviceName}_mock.dart'),
      Directive.import('$serviceName.dart'),
    ];
  }

  /// Builds the main() function with test group.
  Method _buildMainFunction() {
    final mockClassName = 'Mock${service.name}';
    final fieldName = _dartMethodName(service.name);

    return Method(
      (b) => b
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block(
          (block) => block
            ..statements.add(Code('group(\'${service.name}\', () {'))
            ..statements.add(Code('late $mockClassName $fieldName;'))
            ..statements.add(const Code(''))
            ..statements.add(Code('setUp(() {'))
            ..statements.add(Code('$fieldName = $mockClassName();'))
            ..statements.add(const Code('});'))
            ..statements.add(const Code(''))
            ..statements.addAll(service.methods.map(_buildTestMethod))
            ..statements.add(const Code('});')),
        ),
    );
  }

  /// Builds a single test method with commented stub template.
  Code _buildTestMethod(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    final mockFieldName = _dartMethodName(service.name);
    final outputType = method.outputType;

    if (method.isServerStreaming) {
      return Code('''
  test('$methodName returns stream', () async {
    // when($mockFieldName.$methodName(any)).thenAnswer((_) => Stream.value($outputType()));
    // final result = $mockFieldName.$methodName(request);
    // expect(result, isA<Stream<$outputType>>());
  });
''');
    }

    return Code('''
  test('$methodName returns $outputType', () async {
    // when($mockFieldName.$methodName(any)).thenAnswer((_) async => $outputType());
    // final result = await $mockFieldName.$methodName(request);
    // expect(result, isA<$outputType>());
  });
''');
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

  /// Converts proto method name to Dart method name (PascalCase → camelCase).
  String _dartMethodName(String protoName) {
    if (protoName.isEmpty) return protoName;
    return protoName[0].toLowerCase() + protoName.substring(1);
  }
}
