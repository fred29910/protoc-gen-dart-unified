import 'dart:io';
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'parser/descriptor_parser.dart';
import 'generators/service_generator.dart';
import 'generators/mock_service_generator.dart';
import 'generators/example_test_generator.dart';

class CodeGenerator {
  final DescriptorParser _parser = DescriptorParser();

  CodeGeneratorResponse generate(CodeGeneratorRequest request) {
    try {
      final services = _parser.parse(request.protoFile);
      final files = <CodeGeneratorResponse_File>[];
      final mockEnabled = _parseMockParam(request.parameter);

      for (final service in services) {
        // Generate service file
        final serviceGenerator = ServiceGenerator(service);
        final serviceContent = serviceGenerator.generate();
        files.add(CodeGeneratorResponse_File(
          name: '${_dartServiceName(service.name)}.dart',
          content: serviceContent,
        ));

        // Generate mock and example test files (default: enabled)
        if (mockEnabled) {
          final mockGenerator = MockServiceGenerator(service);
          files.add(CodeGeneratorResponse_File(
            name: '${_dartServiceName(service.name)}_mock.dart',
            content: mockGenerator.generate(),
          ));

          final testGenerator = ExampleTestGenerator(service);
          files.add(CodeGeneratorResponse_File(
            name: '${_dartServiceName(service.name)}_example_test.dart',
            content: testGenerator.generate(),
          ));
        }
      }

      return CodeGeneratorResponse(file: files);
    } catch (e, st) {
      return CodeGeneratorResponse(
        error: 'Generation failed: $e\n$st',
      );
    }
  }

  /// Parses the 'mock' plugin parameter from the request parameter string.
  /// Returns true by default (mock generation enabled).
  bool _parseMockParam(String? parameter) {
    if (parameter == null || parameter.isEmpty) return true;
    // Parse comma-separated key=value pairs
    final params = parameter.split(',');
    for (final param in params) {
      final parts = param.trim().split('=');
      if (parts.length == 2 && parts[0].trim() == 'mock') {
        return parts[1].trim() != 'false';
      }
    }
    return true;
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
