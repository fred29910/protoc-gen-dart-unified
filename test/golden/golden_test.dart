import 'package:test/test.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:protoc_gen_dart_unified/src/format_formatter.dart';

void main() {
  group('Golden Tests', () {
    test('generator produces CodeGeneratorResponse', () {
      final request = CodeGeneratorRequest(
        fileToGenerate: ['test/fixtures/user.proto'],
        protoFile: [],
      );
      final generator = CodeGenerator();
      final response = generator.generate(request);
      expect(response.error, isEmpty);
    });

    test('DartFormatter idempotent on generated source', () {
      final source = 'class Foo{int x;}';
      final formatted1 = formatDartSource(source);
      final formatted2 = formatDartSource(formatted1);
      expect(formatted2, equals(formatted1));
    });

    test('generator handles empty request without crash', () {
      final request = CodeGeneratorRequest();
      final generator = CodeGenerator();
      final response = generator.generate(request);
      expect(response.file, isEmpty);
      expect(response.error, isEmpty);
    });
  });
}
