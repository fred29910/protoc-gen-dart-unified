import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/retry_policy.dart';
import 'package:protoc_gen_dart_unified/src/runtime/api_exception.dart';

void main() {
  group('RetryPolicy', () {
    test('default policy has expected values', () {
      const policy = RetryPolicy();
      expect(policy.maxAttempts, equals(3));
      expect(policy.initialDelay, equals(const Duration(milliseconds: 200)));
      expect(policy.maxDelay, equals(const Duration(seconds: 30)));
      expect(policy.backoffMultiplier, equals(2.0));
      expect(policy.jitterFactor, equals(0.25));
    });

    test('shouldRetry returns true for UNAVAILABLE', () {
      const policy = RetryPolicy();
      expect(policy.shouldRetry(const UnavailableException()), isTrue);
    });

    test('shouldRetry returns true for RESOURCE_EXHAUSTED', () {
      const policy = RetryPolicy();
      expect(policy.shouldRetry(const ResourceExhaustedException()), isTrue);
    });

    test('shouldRetry returns true for DEADLINE_EXCEEDED', () {
      const policy = RetryPolicy();
      expect(policy.shouldRetry(const RpcTimeoutException()), isTrue);
    });

    test('shouldRetry returns false for INTERNAL', () {
      const policy = RetryPolicy();
      expect(policy.shouldRetry(const InternalServerException()), isFalse);
    });

    test('shouldRetry returns false for INVALID_ARGUMENT', () {
      const policy = RetryPolicy();
      expect(policy.shouldRetry(const InvalidArgumentException()), isFalse);
    });

    test('shouldRetry returns false for UNAUTHENTICATED', () {
      const policy = RetryPolicy();
      expect(policy.shouldRetry(const UnauthenticatedException()), isFalse);
    });

    test('shouldRetry uses custom predicate when provided', () {
      const policy = RetryPolicy(
        retryIf: _alwaysRetry,
      );
      expect(policy.shouldRetry(const InternalServerException()), isTrue);
    });

    test('delayForAttempt(0) returns zero', () {
      const policy = RetryPolicy();
      expect(policy.delayForAttempt(0), equals(Duration.zero));
    });

    test('delayForAttempt increases exponentially', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
        jitterFactor: 0, // no jitter for deterministic test
        maxDelay: Duration(seconds: 10),
      );
      final d1 = policy.delayForAttempt(1);
      final d2 = policy.delayForAttempt(2);
      final d3 = policy.delayForAttempt(3);
      expect(d1.inMilliseconds, equals(100));
      expect(d2.inMilliseconds, equals(200));
      expect(d3.inMilliseconds, equals(400));
    });

    test('delayForAttempt respects maxDelay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        backoffMultiplier: 10.0,
        jitterFactor: 0,
        maxDelay: Duration(milliseconds: 500),
      );
      final d5 = policy.delayForAttempt(5);
      expect(d5.inMilliseconds, equals(500));
    });
  });
}

bool _alwaysRetry(_) => true;
