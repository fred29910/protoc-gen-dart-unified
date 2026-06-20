import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/transport.dart';

void main() {
  group('Transport abstract', () {
    test('Transport has unaryCall method', () {
      // Verify Transport is abstract and has unaryCall
      expect(Transport, isA<Type>());
    });

    test('Transport has serverStream method', () {
      // This will fail until we add serverStream to Transport
      // ignore: unused_local_variable
      final transport = _TestTransport();
      expect(transport, isA<Transport>());
    });
  });

  group('RpcCallOptions', () {
    test('creates with defaults', () {
      const opts = RpcCallOptions();
      expect(opts.headers, isNull);
      expect(opts.timeout, isNull);
    });

    test('creates with values', () {
      const opts = RpcCallOptions(
        headers: {'Authorization': 'Bearer token'},
        timeout: Duration(seconds: 30),
      );
      expect(opts.headers, equals({'Authorization': 'Bearer token'}));
      expect(opts.timeout, equals(const Duration(seconds: 30)));
    });
  });
}

/// A minimal test implementation of Transport.
class _TestTransport implements Transport {
  @override
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  }) {
    throw UnimplementedError();
  }
}
