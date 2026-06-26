import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';
import '../model/message_model.dart';
import '../builder/http_mapper.dart';
import '../builder/query_field.dart';

/// Generates a complete service file (abstract + unified impl + ApiSdk)
/// using code_builder AST construction.
///
/// Per-service transport selection: if any method has a google.api.http
/// annotation, the entire service uses HTTP transport; otherwise gRPC.
class ServiceGenerator {
  final ServiceModel service;

  ServiceGenerator(this.service);

  /// Whether this service should use HTTP transport.
  bool get _useHttp => service.methods.any((m) => m.httpRule != null);

  /// Generates the complete service file content.
  String generate() {
    final library = Library(
      (b) => b
        ..directives.addAll(_buildDirectives())
        ..body.addAll([
          _buildAbstractInterface(),
          const Code('\n'),
          _buildUnifiedImpl(),
          const Code('\n'),
          _buildApiSdk(),
        ]),
    );

    final emitter = DartEmitter.scoped(useNullSafetySyntax: true);
    final source = library.accept(emitter).toString();
    final formatter = DartFormatter(languageVersion: Version(3, 10, 0));
    return formatter.format('// ignore_for_file: type=lint\n$source');
  }

  List<Directive> _buildDirectives() {
    final directives = <Directive>[
      Directive.import('unified_runtime.dart'),
      Directive.import(
        service.protoFileName.replaceAll('.proto', '.pb.dart'),
      ),
    ];
    if (!_useHttp) {
      directives.add(
        Directive.import(
          '../${service.protoFileName.replaceAll('.proto', '.pbgrpc.dart')}',
        ),
      );
    }
    return directives;
  }

  /// Builds the abstract service interface.
  Class _buildAbstractInterface() {
    return Class(
      (b) => b
        ..name = service.name
        ..abstract = true
        ..methods.addAll(service.methods.map(_buildAbstractMethod)),
    );
  }

  Method _buildAbstractMethod(MethodModel method) {
    final returnType = method.isServerStreaming
        ? refer('Stream<${method.outputType}>')
        : refer('Future<${method.outputType}>');

    return Method(
      (b) => b
        ..name = _dartMethodName(method.name)
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'request'
              ..type = refer(method.inputType),
          ),
        ),
    );
  }

  /// Builds the unified service implementation.
  Class _buildUnifiedImpl() {
    final isGrpc = !_useHttp;

    final fields = <Field>[
      Field(
        (f) => f
          ..name = '_transport'
          ..type = refer('Transport')
          ..modifier = FieldModifier.final$,
      ),
      Field(
        (f) => f
          ..name = '_interceptors'
          ..type = refer('List<RpcInterceptor>')
          ..modifier = FieldModifier.final$,
      ),
    ];

    // For gRPC services, add a _grpcClient field for direct delegation
    if (isGrpc) {
      fields.add(
        Field(
          (f) => f
            ..name = '_grpcClient'
            ..type = refer('GrpcClient')
            ..modifier = FieldModifier.final$,
        ),
      );
    }

    final ctorParams = <Parameter>[
      Parameter(
        (p) => p
          ..name = '_transport'
          ..toThis = true,
      ),
      Parameter(
        (p) => p
          ..name = '_interceptors'
          ..toThis = true,
      ),
    ];

    if (isGrpc) {
      ctorParams.add(
        Parameter(
          (p) => p
            ..name = 'grpcClient'
            ..type = refer('GrpcClient')
            ..toThis = true,
        ),
      );
    }

    return Class(
      (b) => b
        ..name = 'Unified${service.name}'
        ..implements.add(refer(service.name))
        ..fields.addAll(fields)
        ..constructors.add(
          Constructor((c) => c..requiredParameters.addAll(ctorParams)),
        )
        ..methods.addAll(service.methods.map(_buildImplMethod)),
    );
  }

  Method _buildImplMethod(MethodModel method) {
    final methodName = _dartMethodName(method.name);

    return Method(
      (b) => b
        ..name = methodName
        ..annotations.add(refer('override'))
        ..returns = method.isServerStreaming
            ? refer('Stream<${method.outputType}>')
            : refer('Future<${method.outputType}>')
        ..modifier = method.isServerStreaming ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'request'
              ..type = refer(method.inputType),
          ),
        )
        ..body = _buildInterceptedMethodBody(method),
    );
  }

  /// Builds the method body with interceptor chain.
  Code _buildInterceptedMethodBody(MethodModel method) {
    final methodName = _dartMethodName(method.name);

    // Client/Bidi streaming: HTTP transport does not support streaming writes
    if (method.isClientStreaming && _useHttp) {
      return Code(
        "throw UnsupportedError('HTTP transport does not support client streaming for $methodName. "
        "Use gRPC or ConnectRPC instead.');",
      );
    }

    if (method.isServerStreaming) {
      // Server streaming: HTTP uses SSE, gRPC delegates to *ServiceClient
      return _useHttp
          ? _buildHttpServerStreamBody(method)
          : _buildGrpcServerStreamBody(method);
    }

    // Build the core call expression
    final coreCall = _useHttp
        ? _buildHttpUnaryCall(method)
        : _buildGrpcUnaryCall(method);

    // Wrap with interceptor chain
    return Code('''
    final context = InterceptorContext(
      serviceName: '${service.name}',
      methodName: '$methodName',
      request: request,
      options: ${_buildOptionsExpr(method)},
    );
    
    Future<${method.outputType}> call(InterceptorContext ctx) async {
      return await $coreCall;
    }
    
    if (_interceptors.isEmpty) {
      return call(context);
    }
    
    // Build the interceptor chain
    var chain = call;
    for (var i = _interceptors.length - 1; i >= 0; i--) {
      final interceptor = _interceptors[i];
      final next = chain;
      chain = (ctx) => interceptor.intercept(ctx, next);
    }
    return chain(context);
    ''');
  }

  /// Builds the options expression for the method.
  String _buildOptionsExpr(MethodModel method) {
    if (_useHttp && method.httpRule != null) {
      return _buildHttpOptionsExpr(method);
    }
    return 'null';
  }

  /// Builds HTTP options expression.
  String _buildHttpOptionsExpr(MethodModel method) {
    final httpRule = method.httpRule!;
    final inputMessage = service.messages.firstWhere(
      (m) => m.name == method.inputType,
      orElse: () => MessageModel(
        name: method.inputType,
        fullName: method.inputType,
        fields: [],
      ),
    );

    final pathMapping = HttpMapper.mapPath(httpRule.path, inputMessage.fields);
    final bodyMapping = HttpMapper.resolveBody(
      inputMessage.fields,
      httpRule.body,
    );
    final queryFields = bodyMapping.kind == 'all'
        ? <QueryField>[]
        : HttpMapper.flattenQuery(
            inputMessage.fields,
            pathMapping.pathFieldNames.toSet(),
            bodyMapping.kind == 'field' ? bodyMapping.fieldName ?? '' : '',
          );

    final pathInterpolation = StringBuffer();
    for (var i = 0; i < pathMapping.literalSegments.length; i++) {
      pathInterpolation.write(pathMapping.literalSegments[i]);
      if (i < pathMapping.pathFieldNames.length) {
        pathInterpolation.write(
          '\${request.${HttpMapper.toCamelCase(pathMapping.pathFieldNames[i])}}',
        );
      }
    }

    String bodyCode = '';
    if (bodyMapping.kind == 'all') {
      bodyCode = 'httpBody: request.toProto3Json(),';
    } else if (bodyMapping.kind == 'field') {
      bodyCode =
          'httpBody: request.${HttpMapper.toCamelCase(bodyMapping.fieldName!)}.toProto3Json(),';
    }

    String queryCode = '';
    if (queryFields.isNotEmpty) {
      queryCode = 'httpQueryParams: {';
      for (final qf in queryFields) {
        queryCode += "'${qf.name}': request.${qf.dartAccessor}, ";
      }
      queryCode += '},';
    }

    return '''RpcCallOptions(
        httpMethod: '${httpRule.kind}',
        httpPath: '$pathInterpolation',
        $bodyCode
        $queryCode
      )''';
  }

  /// Builds the core HTTP unary call expression (returns the expression string).
  String _buildHttpUnaryCall(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    final httpRule = method.httpRule;

    if (httpRule == null) {
      return "throw UnsupportedError('$methodName has no google.api.http annotation')";
    }

    // When response_body is set, we need to extract a specific field from the response
    if (httpRule.responseBody.isNotEmpty) {
      return '''_transport.unaryCall<Map<String, dynamic>>(
      '${service.name}',
      '$methodName',
      request,
      options: ctx.options,
    ).then((response) => ${method.outputType}.fromProto3Json(response['${httpRule.responseBody}']) as ${method.outputType})''';
    }

    return '''_transport.unaryCall<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
      options: ctx.options,
    )''';
  }

  /// Builds the core gRPC unary call expression.
  String _buildGrpcUnaryCall(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    return '''_transport.unaryCall<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
    )''';
  }

  /// Builds HTTP server streaming body (SSE).
  Code _buildHttpServerStreamBody(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    final httpRule = method.httpRule;

    if (httpRule == null) {
      return Code(
        "throw UnsupportedError('$methodName has no google.api.http annotation');",
      );
    }

    // Build options for SSE
    final inputMessage = service.messages.firstWhere(
      (m) => m.name == method.inputType,
      orElse: () => MessageModel(
        name: method.inputType,
        fullName: method.inputType,
        fields: [],
      ),
    );

    final pathMapping = HttpMapper.mapPath(httpRule.path, inputMessage.fields);
    final queryFields = HttpMapper.flattenQuery(
      inputMessage.fields,
      pathMapping.pathFieldNames.toSet(),
      '',
    );

    final pathInterpolation = StringBuffer();
    for (var i = 0; i < pathMapping.literalSegments.length; i++) {
      pathInterpolation.write(pathMapping.literalSegments[i]);
      if (i < pathMapping.pathFieldNames.length) {
        pathInterpolation.write(
          '\${request.${HttpMapper.toCamelCase(pathMapping.pathFieldNames[i])}}',
        );
      }
    }

    String queryCode = '';
    if (queryFields.isNotEmpty) {
      queryCode = 'httpQueryParams: {';
      for (final qf in queryFields) {
        queryCode += "'${qf.name}': request.${qf.dartAccessor}, ";
      }
      queryCode += '},';
    }

    // Note: additional_bindings are not used in client code generation.
    // The client always uses the primary binding.
    final additionalBindingsComment = httpRule.additionalBindings.isNotEmpty
        ? ' // additional bindings: ${httpRule.additionalBindings.map((b) => '${b.kind} ${b.path}').join(', ')}'
        : '';

    return Code('''
    // HTTP SSE server streaming: ${httpRule.kind} ${httpRule.path}$additionalBindingsComment
    return _transport.serverStream<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
      options: RpcCallOptions(
        httpMethod: '${httpRule.kind}',
        httpPath: '$pathInterpolation',
        $queryCode
      ),
    );
    ''');
  }

  /// Builds gRPC server streaming body — delegates to transport.
  Code _buildGrpcServerStreamBody(MethodModel method) {
    final methodName = _dartMethodName(method.name);
    // gRPC server streaming delegates to GrpcTransport.serverStream,
    // which in turn calls GrpcClient.serverStream on the underlying client.
    return Code('''
    return _transport.serverStream<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
    );
    ''');
  }

  /// Builds the ApiSdk entry class.
  ///
  /// The ApiSdk reads interceptors, retryPolicy, tracingEnabled, and
  /// autoRetryEnabled from [ClientOptions] and builds an effective
  /// interceptor chain via [ClientOptions.buildInterceptorChain].
  /// Additional user-provided interceptors are appended after the chain.
  Class _buildApiSdk() {
    final serviceFieldName = _dartMethodName(service.name);
    final isGrpc = !_useHttp;

    final ctorParams = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'options'
          ..type = refer('ClientOptions')
          ..named = true
          ..required = true,
      ),
      Parameter(
        (p) => p
          ..name = 'extraInterceptors'
          ..type = refer('List<RpcInterceptor>')
          ..defaultTo = const Code('const []')
          ..named = true,
      ),
    ];

    // For gRPC services, add optional grpcClient parameter
    if (isGrpc) {
      ctorParams.add(
        Parameter(
          (p) => p
            ..name = 'grpcClient'
            ..type = refer('GrpcClient')
            ..defaultTo = const Code('null')
            ..named = true,
        ),
      );
    }

    // Build the constructor body: compute chain, then create transport + Unified
    final body = StringBuffer();
    body.writeln(
      'final _chain = options.buildInterceptorChain() + extraInterceptors;',
    );
    if (isGrpc) {
      body.write(
        '$serviceFieldName = Unified${service.name}(createTransport(options.endpoint, grpcClient: grpcClient)!, _chain, grpcClient);',
      );
    } else {
      body.write(
        '$serviceFieldName = Unified${service.name}(createTransport(options.endpoint)!, _chain);',
      );
    }

    return Class(
      (b) => b
        ..name = 'ApiSdk'
        ..fields.add(
          Field(
            (f) => f
              ..name = serviceFieldName
              ..type = refer(service.name)
              ..late = true,
          ),
        )
        ..constructors.add(
          Constructor(
            (c) => c
              ..optionalParameters.addAll(ctorParams)
              ..body = Code(body.toString()),
          ),
        ),
    );
  }

  /// Converts proto method name to Dart method name (PascalCase → camelCase).
  String _dartMethodName(String protoName) {
    if (protoName.isEmpty) return protoName;
    return protoName[0].toLowerCase() + protoName.substring(1);
  }
}
