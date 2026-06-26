import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';

/// Severity level for a validation result.
enum ValidationSeverity { error, warning }

/// A single validation result entry.
class ValidationError {
  final String file;
  final String message;
  final ValidationSeverity severity;

  const ValidationError({
    required this.file,
    required this.message,
    this.severity = ValidationSeverity.error,
  });

  @override
  String toString() => '[$severity] $file: $message';
}

/// Validates a list of [FileDescriptorProto] before code generation.
///
/// Performs structural checks:
/// - At least one proto file must be provided
/// - Each file must define at least one service
/// - Each service must define at least one method
///
/// Only validates — does not modify or repair.
class InputValidator {
  /// Validates [files] and returns a list of [ValidationError] entries.
  /// Returns an empty list if validation passes.
  List<ValidationError> validate(List<FileDescriptorProto> files) {
    final errors = <ValidationError>[];

    if (files.isEmpty) {
      errors.add(
        ValidationError(
          file: '<input>',
          message: 'Request contains no proto files',
        ),
      );
      return errors;
    }

    for (final file in files) {
      if (file.service.isEmpty) {
        errors.add(
          ValidationError(
            file: file.name,
            message: 'File "${file.name}" defines no services',
          ),
        );
        continue; // skip further checks for this file
      }

      for (final service in file.service) {
        if (service.method.isEmpty) {
          errors.add(
            ValidationError(
              file: file.name,
              message:
                  'Service "${service.name}" in "${file.name}" defines no methods',
            ),
          );
        }
      }
    }

    return errors;
  }
}
