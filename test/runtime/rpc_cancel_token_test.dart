import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_cancel_token.dart';

void main() {
  group('RpcCancelToken', () {
    test('starts in non-cancelled state', () {
      final token = RpcCancelToken();
      expect(token.isCancelled, isFalse);
      expect(token.cancelledReason, isNull);
    });

    test('cancel() sets isCancelled to true', () {
      final token = RpcCancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() stores the reason', () {
      final token = RpcCancelToken();
      token.cancel('user requested');
      expect(token.cancelledReason, equals('user requested'));
    });

    test('cancel() without reason stores null', () {
      final token = RpcCancelToken();
      token.cancel();
      expect(token.cancelledReason, isNull);
    });

    test('onCancel() callback fires immediately if already cancelled', () {
      final token = RpcCancelToken();
      token.cancel();
      var called = false;
      token.onCancel(() => called = true);
      expect(called, isTrue);
    });

    test('onCancel() callback fires when cancel() is called later', () {
      final token = RpcCancelToken();
      var called = false;
      token.onCancel(() => called = true);
      expect(called, isFalse);
      token.cancel();
      expect(called, isTrue);
    });

    test('multiple onCancel() callbacks all fire', () {
      final token = RpcCancelToken();
      var count = 0;
      token.onCancel(() => count++);
      token.onCancel(() => count++);
      token.onCancel(() => count++);
      token.cancel();
      expect(count, equals(3));
    });

    test('cancel() is idempotent - callbacks fire only once', () {
      final token = RpcCancelToken();
      var count = 0;
      token.onCancel(() => count++);
      token.cancel();
      token.cancel();
      token.cancel();
      expect(count, equals(1));
    });

    test('throwIfCancelled() does not throw when not cancelled', () {
      final token = RpcCancelToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled() throws RpcCancelledException when cancelled', () {
      final token = RpcCancelToken();
      token.cancel('test reason');
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<RpcCancelledException>()),
      );
    });

    test('RpcCancelledException contains reason', () {
      const exception = RpcCancelledException('timeout');
      expect(exception.reason, equals('timeout'));
      expect(exception.toString(), contains('timeout'));
    });

    test('RpcCancelledException with null reason', () {
      const exception = RpcCancelledException();
      expect(exception.reason, isNull);
      expect(exception.toString(), equals('RpcCancelledException'));
    });
  });
}
