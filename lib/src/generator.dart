import 'dart:io';
import 'package:fixnum/fixnum.dart';
// ignore: implementation_imports
import 'package:protoc_plugin/src/gen/google/protobuf/compiler/plugin.pb.dart';
import 'parser/descriptor_parser.dart';
import 'parser/input_validator.dart';
import 'generators/generator_registry.dart';

class CodeGenerator {
  final DescriptorParser _parser = DescriptorParser();
  final InputValidator _validator = InputValidator();

  CodeGeneratorResponse generate(CodeGeneratorRequest request) {
    try {
      // Only validate when there are files to generate
      // (empty fileToGenerate is a supported-features probe)
      final filesToGenerate = request.protoFile
          .where((f) => request.fileToGenerate.contains(f.name))
          .toList();
      if (filesToGenerate.isNotEmpty) {
        final errors = _validator.validate(filesToGenerate);
        if (errors.isNotEmpty) {
          final errorMsg = errors.map((e) => e.toString()).join('\n');
          return CodeGeneratorResponse(error: errorMsg);
        }
      }

      final services = _parser.parse(request.protoFile);
      final mockEnabled = _parseMockParam(request.parameter);
      final registry = GeneratorRegistry.defaultRegistry(mockEnabled: mockEnabled);
      final files = <CodeGeneratorResponse_File>[];

      for (final service in services) {
        final dartName = _dartServiceName(service.name);
        for (final (fileName, content) in registry.generateForService(service, dartName)) {
          files.add(CodeGeneratorResponse_File(
            name: fileName,
            content: content,
          ));
        }
      }

      // Emit global files once per request (e.g. unified_runtime.dart)
      for (final (fileName, content) in registry.generateGlobal()) {
        files.insert(0, CodeGeneratorResponse_File(
          name: fileName,
          content: content,
        ));
      }

      return CodeGeneratorResponse(
        file: files,
        supportedFeatures: Int64(1), // FEATURE_PROTO3_OPTIONAL
      );
    } catch (e, st) {
      return CodeGeneratorResponse(error: 'Generation failed: $e\n$st');
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
    return protoName
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst('_', '');
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
