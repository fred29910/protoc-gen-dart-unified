import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';

/// Generates a complete service file (abstract + unified impl + ApiSdk)
/// using code_builder AST construction.
///
/// Per-service transport selection: if any method has a google.api.http
/// annotation, the entire service uses HTTP transport; otherwise gRPC.
class ServiceGenerator {
  final ServiceModel service;

  ServiceGenerator(this.service);

  /// Whether this service should use HTTP transport.
  bool get _useHttp =>
      service.methods.any((m) => m.httpRule != null);

  /// Generates the complete service file content.
  String generate() {
    final library = Library((b) => b
      ..directives.addAll(_buildDirectives())
      ..body.addAll([
        _buildAbstractInterface(),
        const Code('\n'),
        _buildUnifiedImpl(),
        const Code('\n'),
        _buildApiSdk(),
      ]));

    final emitter = DartEmitter.scoped();
    final source = library.accept(emitter).toString();
    final formatter = DartFormatter(
        languageVersion: Version(3, 10, 0));
    try {
      return formatter.format(source);
    } on FormatterException {
      return source;
    }
  }

  List<Directive> _buildDirectives() {
    final directives = <Directive>[
      Directive.import('package:protobuf/protobuf.dart'),
      Directive.import('package:dio/dio.dart'),
      Directive.import('../${service.name.toLowerCase()}.pb.dart'),
    ];
    if (!_useHttp) {
      directives.add(Directive.import(
          '../${service.name.toLowerCase()}.pbgrpc.dart'));
    }
    return directives;
  }

  /// Builds the abstract service interface.
  Class _buildAbstractInterface() {
    return Class((b) => b
      ..name = service.name
      ..abstract = true
      ..methods.addAll(service.methods.map(_buildAbstractMethod)));
  }

  Method _buildAbstractMethod(MethodModel method) {
    final returnType = method.isServerStreaming
        ? refer('Stream<${method.outputType}>')
        : refer('Future<${method.outputType}>');

    return Method((b) => b
      ..name = _dartMethodName(method.name)
      ..returns = returnType
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'request'
        ..type = refer(method.inputType))));
  }

  /// Builds the unified service implementation.
  Class _buildUnifiedImpl() {
    return Class((b) => b
      ..name = 'Unified${service.name}'
      ..implements.add(refer(service.name))
      ..fields.add(Field((f) => f
        ..name = '_transport'
        ..type = refer('Transport')
        ..modifier = FieldModifier.final$))
      ..constructors.add(Constructor((c) => c
        ..requiredParameters.add(Parameter((p) => p
          ..name = '_transport'
          ..toThis = true))))
      ..methods.addAll(service.methods.map(_buildImplMethod)));
  }

  Method _buildImplMethod(MethodModel method) {
    final methodName = _dartMethodName(method.name);

    return Method((b) => b
      ..name = methodName
      ..annotations.add(refer('override'))
      ..returns = method.isServerStreaming
          ? refer('Stream<${method.outputType}>')
          : refer('Future<${method.outputType}>')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'request'
        ..type = refer(method.inputType)))
      ..body = _useHttp
          ? _buildHttpMethodBody(method)
          : _buildGrpcMethodBody(method));
  }

  Code _buildHttpMethodBody(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    final httpRule = method.httpRule;

    if (httpRule == null) {
      return Code(
          "throw UnsupportedError('$methodName has no google.api.http annotation');");
    }

    final path = httpRule.path;
    final httpMethod = httpRule.kind;

    // Build path interpolation
    var interpolatedPath = path;
    final regex = RegExp(r'\{([^}]+)\}');
    for (final match in regex.allMatches(path)) {
      final field = match.group(1)!;
      final cleanField = field.contains('=') ? field.split('=')[0] : field;
      interpolatedPath = interpolatedPath
          .replaceFirst('{$field}', '\${request.$cleanField}');
    }

    // Build body code
    final bodyCode = httpRule.body == '*'
        ? 'data: request.toProto3Json()'
        : httpRule.body.isNotEmpty
            ? 'data: request.${httpRule.body}.toProto3Json()'
            : '';

    if (method.isServerStreaming) {
      return Code('''
      // TODO: HTTP server streaming (SSE) — Phase 3
      throw UnimplementedError('HTTP server streaming for \$methodName not yet implemented');
      ''');
    }

    return Code('''
    // HTTP $httpMethod $interpolatedPath
    ${bodyCode.isNotEmpty ? '// Body: $bodyCode' : '// No body'}
    final response = await _transport.unaryCall<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
    );
    return response;
    ''');
  }

  Code _buildGrpcMethodBody(MethodModel method) {
    final methodName = _dartMethodName(method.name);

    if (method.isServerStreaming) {
      return Code('''
      return _transport.serverStream<${method.outputType}>(
        '${service.name}',
        '$methodName',
        request,
      );
      ''');
    }

    return Code('''
    return _transport.unaryCall<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
    );
    ''');
  }

  /// Builds the ApiSdk entry class.
  Class _buildApiSdk() {
    final serviceFieldName = _dartMethodName(service.name);

    return Class((b) => b
      ..name = 'ApiSdk'
      ..fields.add(Field((f) => f
        ..name = '_options'
        ..type = refer('ClientOptions')
        ..modifier = FieldModifier.final$))
      ..fields.add(Field((f) => f
        ..name = serviceFieldName
        ..type = refer(service.name)
        ..late = true))
      ..constructors.add(Constructor((c) => c
        ..requiredParameters.add(Parameter((p) => p
          ..name = '_options'
          ..toThis = true))
          ..body = Code('''
          final transport = createTransport(_options.endpoint);
          $serviceFieldName = Unified${service.name}(transport);
          '''))));
  }

  /// Converts proto method name to Dart method name (PascalCase → camelCase).
  String _dartMethodName(String protoName) {
    if (protoName.isEmpty) return protoName;
    return protoName[0].toLowerCase() + protoName.substring(1);
  }
}
