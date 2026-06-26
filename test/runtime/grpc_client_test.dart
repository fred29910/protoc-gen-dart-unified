import 'dart:async';
import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/grpc_client.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_call_options.dart';

/// A concrete GrpcClient implementation for testing.
class TestGrpcClient extends GrpcClient {
  final Map<String, Object?> _responses = {};

  void registerResponse<T>(String key, T response) {
    _responses[key] = response;
  }

  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) async {
    final key = '$serviceName.$methodName';
    final response = _responses[key];
    if (response == null) {
      throw StateError('No registered response for $key');
    }
    return response as T;
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    final key = '$serviceName.$methodName';
    final response = _responses[key];
    if (response == null) {
      throw StateError('No registered response for $key');
    }
    return Stream.value(response as T);
  }
}

class _FakeRequest {
  final String value;
  _FakeRequest(this.value);
}

class _FakeResponse {
  final String result;
  _FakeResponse(this.result);
}

void main() {
  group('GrpcClient abstract interface', () {
    test('can be extended with concrete implementation', () {
      final client = TestGrpcClient();
      expect(client, isA<GrpcClient>());
    });

    test('unaryCall returns typed response', () async {
      final client = TestGrpcClient();
      client.registerResponse(
        'UserService.GetUser',
        _FakeResponse('user-data'),
      );

      final response = await client.unaryCall<_FakeResponse>(
        'UserService',
        'GetUser',
        _FakeRequest('id-123'),
      );

      expect(response, isA<_FakeResponse>());
      expect(response.result, equals('user-data'));
    });

    test('serverStream returns typed response stream', () async {
      final client = TestGrpcClient();
      client.registerResponse(
        'UserService.ListUsers',
        _FakeResponse('user-stream-data'),
      );

      final stream = client.serverStream<_FakeResponse>(
        'UserService',
        'ListUsers',
        _FakeRequest('query'),
      );

      final results = await stream.toList();
      expect(results, hasLength(1));
      expect(results.first.result, equals('user-stream-data'));
    });

    test('unaryCall passes RpcCallOptions', () async {
      final capturedOptions = <RpcCallOptions?>[];
      final client = _CallOptionCapturingClient(capturedOptions);
      client.registerResponse(
        'TestService.TestMethod',
        'result',
      );

      final options = RpcCallOptions(
        httpMethod: 'POST',
        headers: {'x-test': 'true'},
      );

      await client.unaryCall<String>(
        'TestService',
        'TestMethod',
        'request',
        options: options,
      );

      expect(capturedOptions, hasLength(1));
      expect(capturedOptions.first?.httpMethod, equals('POST'));
      expect(capturedOptions.first?.headers?['x-test'], equals('true'));
    });
  });
}

class _CallOptionCapturingClient extends TestGrpcClient {
  final List<RpcCallOptions?> captured;

  _CallOptionCapturingClient(this.captured);

  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    captured.add(options);
    return super.unaryCall<T>(
      serviceName,
      methodName,
      request,
      options: options,
    );
  }
}
