import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/with_retry.dart';
import 'package:protoc_gen_dart_unified/src/runtime/retry_policy.dart';
import 'package:protoc_gen_dart_unified/src/runtime/api_exception.dart';

void main() {
  group('withRetry', () {
    test('succeeds on first attempt without retry', () async {
      var attempts = 0;
      final result = await withRetry(
        () async {
          attempts++;
          return 'success';
        },
        RetryPolicy(maxAttempts: 3),
      );
      expect(result, equals('success'));
      expect(attempts, equals(1));
    });

    test('retries on retryable error up to maxAttempts', () async {
      var attempts = 0;
      final policy = RetryPolicy(
        maxAttempts: 2,
        initialDelay: Duration(milliseconds: 1),
        jitterFactor: 0,
      );

      await expectLater(
        withRetry(
          () async {
            attempts++;
            throw UnavailableException('temporary failure');
          },
          policy,
        ),
        throwsA(isA<UnavailableException>()),
      );

      // 1 initial + 2 retries = 3 total attempts
      expect(attempts, equals(3));
    });

    test('succeeds after transient failures', () async {
      var attempts = 0;
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 1),
        jitterFactor: 0,
      );

      final result = await withRetry(
        () async {
          attempts++;
          if (attempts < 3) throw UnavailableException('not yet');
          return 'done';
        },
        policy,
      );

      expect(result, equals('done'));
      expect(attempts, equals(3));
    });

    test('does not retry on non-retryable error', () async {
      var attempts = 0;
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 1),
        retryIf: (e) => e is UnavailableException,
      );

      await expectLater(
        withRetry(
          () async {
            attempts++;
            throw InvalidArgumentException('bad request');
          },
          policy,
        ),
        throwsA(isA<InvalidArgumentException>()),
      );

      expect(attempts, equals(1));
    });

    test('custom shouldRetry predicate overrides policy', () async {
      var attempts = 0;
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 1),
        // Default would retry UnavailableException
      );

      final result = await withRetry(
        () async {
          attempts++;
          if (attempts < 3) throw UnavailableException('retry me');
          return 'done';
        },
        policy,
        shouldRetry: (e) => e is UnavailableException,
      );

      expect(result, equals('done'));
      expect(attempts, equals(3));
    });

    test('exponential backoff delay increases', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
        backoffMultiplier: 2.0,
        jitterFactor: 0, // no jitter for deterministic test
      );

      // Verify delay calculation
      expect(policy.delayForAttempt(1), equals(Duration(milliseconds: 10)));
      expect(policy.delayForAttempt(2), equals(Duration(milliseconds: 20)));
      expect(policy.delayForAttempt(3), equals(Duration(milliseconds: 40)));
    });

    test('delay clamps to maxDelay', () {
      final policy = RetryPolicy(
        maxAttempts: 10,
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 1),
        backoffMultiplier: 10.0,
        jitterFactor: 0,
      );

      // attempt 10 would be 100 * 10^9 = 1e11 ms, clamped to 1000ms
      final delay = policy.delayForAttempt(10);
      expect(delay.inMilliseconds, lessThanOrEqualTo(1000));
    });
  });
}
