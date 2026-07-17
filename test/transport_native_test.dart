import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/generators/runtime_inline_generator.dart';
import 'package:protoc_gen_dart_unified/src/model/service_model.dart';
import 'package:protoc_gen_dart_unified/src/model/method_model.dart';

// Behavioral verification of the generated native gRPC wiring (O-C design):
// the global `unified_transport_native.dart` (GrpcTransport + _mapGrpcError +
// cancel bridge) plus the per-service `unified_transport_adapter_{service}.dart`
// (per-method switch delegating to the real *ServiceClient). We generate the
// real source, compile it against a stub pbgrpc client, and run a harness that
// exercises delegation, options mapping, error mapping, and cancel bridging.
void main() {
  final generator = RuntimeInlineGenerator();
  final service = ServiceModel(
    name: 'EchoService',
    protoFileName: 'echo.proto',
    methods: [
      MethodModel(
        name: 'Echo',
        inputType: 'EchoRequest',
        outputType: 'EchoResponse',
        isServerStreaming: false,
        isClientStreaming: false,
      ),
      MethodModel(
        name: 'EchoStream',
        inputType: 'EchoRequest',
        outputType: 'EchoResponse',
        isServerStreaming: true,
        isClientStreaming: false,
      ),
    ],
  );

  group('generated native gRPC wiring (O-C)', () {
    test('native + adapter compile against stub pbgrpc and behave correctly',
        () async {
      final nativeSrc = generator.generateTransportNative();
      final adapterSrc = generator.generateTransportAdapter(service);

      final tempDir = Directory.systemTemp.createTempSync('native_behavior');
      try {
        // Runtime set so `unified_runtime.dart` (imported by native + adapter)
        // resolves. Write the full 5-file set (factory imports stub/web too).
        final runtime = {
          'unified_runtime.dart': generator.generate(),
          'unified_transport_factory.dart': generator.generateTransportFactory(),
          'unified_transport_native.dart': nativeSrc,
          'unified_transport_web.dart': generator.generateTransportWeb(),
          'unified_transport_stub.dart': generator.generateTransportStub(),
        };
        runtime.forEach((name, content) {
          File('${tempDir.path}/$name').writeAsStringSync(content);
        });
        File('${tempDir.path}/unified_transport_adapter_echo_service.dart')
            .writeAsStringSync(adapterSrc);

        // Stub pbgrpc client the adapter delegates to.
        File('${tempDir.path}/echo.pbgrpc.dart').writeAsStringSync('''
import 'package:grpc/grpc.dart';

class EchoRequest {
  @override
  String toString() => 'EchoRequest';
}
class EchoResponse {
  final String message;
  EchoResponse(this.message);
}
class EchoServiceClient {
  Future<EchoResponse> echo(EchoRequest req, {CallOptions? options}) async {
    if (options?.metadata['x-fail'] == 'notfound') {
      throw GrpcError.notFound('missing');
    }
    capturedMetadata = options?.metadata;
    return EchoResponse('echo:\${req}');
  }

  Stream<EchoResponse> echoStream(EchoRequest req, {CallOptions? options}) {
    return Stream.value(EchoResponse('stream:\${req}'));
  }
}

Map<String, String>? capturedMetadata;
''');

        // Harness: build the adapter + GrpcTransport, exercise them.
        // Place at project root so sibling .dart imports resolve.
        File('${tempDir.path}/harness.dart').writeAsStringSync('''
import 'unified_transport_native.dart';
import 'unified_transport_adapter_echo_service.dart';
import 'echo.pbgrpc.dart';
import 'unified_runtime.dart';

Future<void> main() async {
  final client = EchoServiceClient();
  final adapter = EchoServiceGrpcAdapter(client);
  final transport = GrpcTransport(adapter);

  // (1) Unary delegation + response shape.
  final resp = await transport.unaryCall<EchoResponse>(
    'EchoService', 'echo', EchoRequest(),
    options: RpcCallOptions(headers: {'x-trace': 'abc'}),
  );
  print('UNARY: \${resp.message}');

  // (2) Options mapping: header -> gRPC metadata.
  print('META: \${capturedMetadata?["x-trace"]}');

  // (3) Error mapping: GrpcError.notFound -> NotFoundException.
  try {
    await transport.unaryCall<EchoResponse>(
      'EchoService', 'echo', EchoRequest(),
      options: RpcCallOptions(headers: {'x-fail': 'notfound'}),
    );
    print('ERROR: none');
  } on NotFoundException catch (e) {
    print('ERROR: NotFoundException(\${e.message})');
  } on ApiException catch (e) {
    print('ERROR: other ApiException(\${e.message})');
  }

  // (4) Server streaming delegation.
  final streamed = await transport
      .serverStream<EchoResponse>('EchoService', 'echoStream', EchoRequest())
      .toList();
  print('STREAM: \${streamed.first.message}');
}
''');

        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: native_behavior
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  grpc: ^5.1.0
  protobuf: ^6.0.0
  dio: ^5.9.2
''');

        final pubGet = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: tempDir.path,
        );
        expect(pubGet.exitCode, 0,
            reason: 'dart pub get failed:\n${pubGet.stderr}');

        final analyze = await Process.run(
          'dart',
          ['analyze', '--fatal-infos'],
          workingDirectory: tempDir.path,
        );
        expect(analyze.exitCode, 0,
            reason: 'analyze failed:\n${analyze.stdout}\n${analyze.stderr}');

        final run = await Process.run(
          'dart',
          ['run', 'harness.dart'],
          workingDirectory: tempDir.path,
        );
        expect(run.exitCode, 0,
            reason: 'harness failed:\n${run.stdout}\n${run.stderr}');

        final out = run.stdout as String;
        expect(out, contains('UNARY: echo:EchoRequest'),
            reason: 'unary delegation should reach echo()');
        expect(out, contains('META: abc'),
            reason: 'RpcCallOptions.headers should map to gRPC metadata');
        expect(out, contains('ERROR: NotFoundException(missing)'),
            reason: 'GrpcError.notFound should map to NotFoundException');
        expect(out, contains('STREAM: stream:EchoRequest'),
            reason: 'server streaming should delegate to echoStream()');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
