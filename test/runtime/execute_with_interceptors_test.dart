import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/transport.dart';
import 'package:protoc_gen_dart_unified/src/runtime/rpc_interceptor.dart';

void main() {
  group('executeWithInterceptors', () {
    test('calls finalCall directly when interceptors list is empty', () async {
      final transport = _StubTransport();

      final result = await transport.executeWithInterceptors<String>(
        'TestService',
        'TestMethod',
        'request',
        null,
        [], // empty interceptors
        (req, opts) async => 'result:$req',
      );

      expect(result, equals('result:request'));
    });

    test('single interceptor wraps the call', () async {
      final transport = _StubTransport();
      final log = <String>[];

      final interceptor = _LoggingInterceptor(log, 'A');

      final result = await transport.executeWithInterceptors<String>(
        'TestService',
        'TestMethod',
        'request',
        null,
        [interceptor],
        (req, opts) async {
          log.add('finalCall');
          return 'result';
        },
      );

      expect(result, equals('result'));
      expect(log, equals(['A:before', 'finalCall', 'A:after']));
    });

    test('multiple interceptors execute in order', () async {
      final transport = _StubTransport();
      final log = <String>[];

      final interceptorA = _LoggingInterceptor(log, 'A');
      final interceptorB = _LoggingInterceptor(log, 'B');

      await transport.executeWithInterceptors<String>(
        'TestService',
        'TestMethod',
        'request',
        null,
        [interceptorA, interceptorB],
        (req, opts) async {
          log.add('finalCall');
          return 'result';
        },
      );

      expect(log, equals(['A:before', 'B:before', 'finalCall', 'B:after', 'A:after']));
    });

    test('interceptor can modify request', () async {
      final transport = _StubTransport();

      final modifier = _ModifyRequestInterceptor('modified');

      final result = await transport.executeWithInterceptors<String>(
        'TestService',
        'TestMethod',
        'original',
        null,
        [modifier],
        (req, opts) async => req as String,
      );

      expect(result, equals('modified'));
    });

    test('interceptor can modify options', () async {
      final transport = _StubTransport();

      final modifier = _ModifyOptionsInterceptor();

      final result = await transport.executeWithInterceptors<RpcCallOptions?>(
        'TestService',
        'TestMethod',
        'request',
        null,
        [modifier],
        (req, opts) async => opts,
      );

      expect(result, isNotNull);
      expect(result!.headers, equals({'X-Custom': 'modified'}));
    });

    test('interceptor can short-circuit the chain', () async {
      final transport = _StubTransport();
      final log = <String>[];

      final shortcircuit = _ShortCircuitInterceptor('shortcircuited');
      final neverCalled = _LoggingInterceptor(log, 'NEVER');

      final result = await transport.executeWithInterceptors<String>(
        'TestService',
        'TestMethod',
        'request',
        null,
        [shortcircuit, neverCalled],
        (req, opts) async {
          log.add('finalCall');
          return 'original';
        },
      );

      expect(result, equals('shortcircuited'));
      // neverCalled should not have been invoked
      expect(log, isEmpty);
    });

    test('propagates exceptions through interceptor chain', () async {
      final transport = _StubTransport();

      final rethrowInterceptor = _RethrowInterceptor();

      expect(
        () => transport.executeWithInterceptors<String>(
          'TestService',
          'TestMethod',
          'request',
          null,
          [rethrowInterceptor],
          (req, opts) async => throw Exception('test error'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

/// A minimal Transport implementation for testing.
class _StubTransport extends Transport {
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

/// Interceptor that logs before/after calls.
class _LoggingInterceptor implements RpcInterceptor {
  final List<String> _log;
  final String _name;

  _LoggingInterceptor(this._log, this._name);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    _log.add('$_name:before');
    final result = await proceed(context);
    _log.add('$_name:after');
    return result;
  }
}

/// Interceptor that modifies the request.
class _ModifyRequestInterceptor implements RpcInterceptor {
  final String _newRequest;

  _ModifyRequestInterceptor(this._newRequest);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    return proceed(context.copyWith(request: _newRequest));
  }
}

/// Interceptor that modifies the options.
class _ModifyOptionsInterceptor implements RpcInterceptor {
  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    final baseOptions = context.options ?? const RpcCallOptions();
    final newOptions = baseOptions.copyWith(
      headers: {'X-Custom': 'modified'},
    );
    return proceed(context.copyWith(options: newOptions));
  }
}

/// Interceptor that short-circuits the chain.
class _ShortCircuitInterceptor implements RpcInterceptor {
  final String _returnValue;

  _ShortCircuitInterceptor(this._returnValue);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    return _returnValue as T;
  }
}

/// Interceptor that passes through (for rethrow testing).
class _RethrowInterceptor implements RpcInterceptor {
  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    return proceed(context);
  }
}
