import 'package:test/test.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'package:protoc_gen_dart_unified/src/parser/input_validator.dart';

void main() {
  group('InputValidator', () {
    late InputValidator validator;

    setUp(() {
      validator = InputValidator();
    });

    test('validates a valid FileDescriptorProto list', () {
      final files = [
        FileDescriptorProto()
          ..name = 'valid.proto'
          ..service.add(ServiceDescriptorProto()
            ..name = 'ValidService'
            ..method.add(MethodDescriptorProto()
              ..name = 'TestMethod')),
      ];
      final errors = validator.validate(files);
      expect(errors, isEmpty);
    });

    test('returns error for empty file list', () {
      final errors = validator.validate([]);
      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('no proto files'));
    });

    test('returns error for file without services', () {
      final files = [
        FileDescriptorProto()
          ..name = 'nope.proto'
          ..messageType.add(DescriptorProto()..name = 'SomeMessage'),
      ];
      final errors = validator.validate(files);
      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('no services'));
    });

    test('returns error for service without methods', () {
      final files = [
        FileDescriptorProto()
          ..name = 'empty_service.proto'
          ..service.add(ServiceDescriptorProto()..name = 'EmptyService'),
      ];
      final errors = validator.validate(files);
      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('no methods'));
    });

    test('reports errors per file with file name and severity', () {
      final error = ValidationError(
        file: 'test.proto',
        message: 'Test error',
        severity: ValidationSeverity.error,
      );
      expect(error.file, equals('test.proto'));
      expect(error.message, equals('Test error'));
      expect(error.severity, equals(ValidationSeverity.error));
      expect(error.toString(), contains('test.proto'));
    });

    test('reports warnings without blocking', () {
      final warning = ValidationError(
        file: 'warn.proto',
        message: 'Test warning',
        severity: ValidationSeverity.warning,
      );
      expect(warning.severity, equals(ValidationSeverity.warning));
    });

    test('detects empty service name', () {
      final files = [
        FileDescriptorProto()
          ..name = 'anon.proto'
          ..service.add(ServiceDescriptorProto()
            ..name = ''
            ..method.add(MethodDescriptorProto()..name = 'DoSomething')),
      ];
      final errors = validator.validate(files);
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.message.contains('empty') || e.message.contains('unnamed')), isTrue);
    });

    test('detects duplicate method names in same service', () {
      final files = [
        FileDescriptorProto()
          ..name = 'dup.proto'
          ..service.add(ServiceDescriptorProto()
            ..name = 'DupService'
            ..method.addAll([
              MethodDescriptorProto()..name = 'GetUser',
              MethodDescriptorProto()..name = 'GetUser',
            ])),
      ];
      final errors = validator.validate(files);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Duplicate'));
    });

    test('detects duplicate method names across different services', () {
      final files = [
        FileDescriptorProto()
          ..name = 'multi.proto'
          ..service.addAll([
            ServiceDescriptorProto()
              ..name = 'UserService'
              ..method.add(MethodDescriptorProto()..name = 'GetUser'),
            ServiceDescriptorProto()
              ..name = 'AdminService'
              ..method.add(MethodDescriptorProto()..name = 'GetUser'),
          ]),
      ];
      final errors = validator.validate(files);
      // Same method name in different services is valid
      expect(errors, isEmpty);
    });
  });
}
