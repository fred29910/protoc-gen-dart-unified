import 'dart:io';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'parser/descriptor_parser.dart';
import 'generators/service_generator.dart';

class CodeGenerator {
  final DescriptorParser _parser = DescriptorParser();

  CodeGeneratorResponse generate(CodeGeneratorRequest request) {
    try {
      final services = _parser.parse(request.protoFile);
      final files = <CodeGeneratorResponse_File>[];

      for (final service in services) {
        final generator = ServiceGenerator(service);
        final content = generator.generate();
        files.add(CodeGeneratorResponse_File(
          name: '${_dartServiceName(service.name)}_service.dart',
          content: content,
        ));
      }

      return CodeGeneratorResponse(file: files);
    } catch (e, st) {
      return CodeGeneratorResponse(
        error: 'Generation failed: $e\n$st',
      );
    }
  }

  /// Converts proto service name to Dart file name (PascalCase → snake_case).
  String _dartServiceName(String protoName) {
    return protoName.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst('_', '');
  }
}

Future<void> runCodeGenerator() async {
  final bytes = <int>[];
  await for (final chunk in stdin) {
    bytes.addAll(chunk);
  }
  final request = CodeGeneratorRequest.fromBuffer(bytes);
  final generator = CodeGenerator();
  final response = generator.generate(request);
  stdout.add(response.writeToBuffer());
}
