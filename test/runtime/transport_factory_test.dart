import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/transport_factory.dart';
import 'package:protoc_gen_dart_unified/src/runtime/transport.dart';

void main() {
  group('Transport Factory', () {
    test('createTransport returns a Transport or null', () {
      final transport = createTransport('https://api.example.com');
      // On native (dart.library.io), returns null (placeholder)
      // On web (dart.library.js_interop), returns null (placeholder)
      // Either way, should not throw
      expect(transport, isA<Transport?>());
    });

    test('createTransport does not throw', () {
      expect(() => createTransport('https://api.example.com'), returnsNormally);
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
