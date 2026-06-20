import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/protocol.dart';
import 'package:protoc_gen_dart_unified/src/runtime/client_options.dart';
import 'package:protoc_gen_dart_unified/src/runtime/api_exception.dart';
import 'package:protoc_gen_dart_unified/src/runtime/http_status_mapping.dart';

void main() {
  group('Protocol', () {
    test('has auto, http, grpc values', () {
      expect(Protocol.values.length, equals(3));
      expect(Protocol.auto, isNotNull);
      expect(Protocol.http, isNotNull);
      expect(Protocol.grpc, isNotNull);
    });
  });

  group('ClientOptions', () {
    test('creates with required endpoint', () {
      const opts = ClientOptions(endpoint: 'https://api.example.com');
      expect(opts.endpoint, equals('https://api.example.com'));
      expect(opts.protocol, equals(Protocol.auto));
      expect(opts.timeout, isNull);
    });

    test('creates with all fields', () {
      const opts = ClientOptions(
        endpoint: 'https://api.example.com',
        protocol: Protocol.grpc,
        timeout: Duration(seconds: 30),
      );
      expect(opts.protocol, equals(Protocol.grpc));
      expect(opts.timeout, equals(const Duration(seconds: 30)));
    });
  });

  group('ApiException', () {
    test('base exception has message and code', () {
      const e = InvalidArgumentException('bad input');
      expect(e.message, equals('bad input'));
      expect(e.code, equals(3));
      expect(e.toString(), contains('ApiException'));
      expect(e.toString(), contains('bad input'));
    });

    test('all 17 canonical codes have exception types', () {
      // Verify all exception types can be constructed
      expect(const InvalidArgumentException().code, equals(3));
      expect(const UnauthenticatedException().code, equals(16));
      expect(const PermissionDeniedException().code, equals(7));
      expect(const NotFoundException().code, equals(5));
      expect(const ResourceExhaustedException().code, equals(8));
      expect(const InternalServerException().code, equals(13));
      expect(const RpcTimeoutException().code, equals(4));
      expect(const CancelledException().code, equals(1));
      expect(const UnknownException().code, equals(2));
      expect(const AlreadyExistsException().code, equals(6));
      expect(const AbortedException().code, equals(10));
      expect(const OutOfRangeException().code, equals(11));
      expect(const UnimplementedException().code, equals(12));
      expect(const UnavailableException().code, equals(14));
      expect(const DataLossException().code, equals(15));
      expect(const FailedPreconditionException().code, equals(9));
    });
  });

  group('HttpStatusMapping', () {
    test('grpcCodeToHttpStatus covers all 17 codes', () {
      expect(grpcCodeToHttpStatus(0), equals(200));   // OK
      expect(grpcCodeToHttpStatus(1), equals(500));   // CANCELLED
      expect(grpcCodeToHttpStatus(2), equals(500));   // UNKNOWN
      expect(grpcCodeToHttpStatus(3), equals(400));   // INVALID_ARGUMENT
      expect(grpcCodeToHttpStatus(4), equals(504));   // DEADLINE_EXCEEDED
      expect(grpcCodeToHttpStatus(5), equals(404));   // NOT_FOUND
      expect(grpcCodeToHttpStatus(6), equals(409));   // ALREADY_EXISTS
      expect(grpcCodeToHttpStatus(7), equals(403));   // PERMISSION_DENIED
      expect(grpcCodeToHttpStatus(9), equals(400));   // FAILED_PRECONDITION
      expect(grpcCodeToHttpStatus(10), equals(409));  // ABORTED
      expect(grpcCodeToHttpStatus(11), equals(400));  // OUT_OF_RANGE
      expect(grpcCodeToHttpStatus(12), equals(501));  // UNIMPLEMENTED
      expect(grpcCodeToHttpStatus(13), equals(500));  // INTERNAL
      expect(grpcCodeToHttpStatus(14), equals(503));  // UNAVAILABLE
      expect(grpcCodeToHttpStatus(15), equals(500));  // DATA_LOSS
      expect(grpcCodeToHttpStatus(16), equals(401));  // UNAUTHENTICATED
      expect(grpcCodeToHttpStatus(99), equals(500));  // unknown -> 500
    });

    test('grpcCodeToExceptionName covers all 17 codes', () {
      expect(grpcCodeToExceptionName(0), equals('InternalServerException'));
      expect(grpcCodeToExceptionName(1), equals('CancelledException'));
      expect(grpcCodeToExceptionName(2), equals('UnknownException'));
      expect(grpcCodeToExceptionName(3), equals('InvalidArgumentException'));
      expect(grpcCodeToExceptionName(4), equals('RpcTimeoutException'));
      expect(grpcCodeToExceptionName(5), equals('NotFoundException'));
      expect(grpcCodeToExceptionName(6), equals('AlreadyExistsException'));
      expect(grpcCodeToExceptionName(7), equals('PermissionDeniedException'));
      expect(grpcCodeToExceptionName(9), equals('FailedPreconditionException'));
      expect(grpcCodeToExceptionName(10), equals('AbortedException'));
      expect(grpcCodeToExceptionName(11), equals('OutOfRangeException'));
      expect(grpcCodeToExceptionName(12), equals('UnimplementedException'));
      expect(grpcCodeToExceptionName(13), equals('InternalServerException'));
      expect(grpcCodeToExceptionName(14), equals('UnavailableException'));
      expect(grpcCodeToExceptionName(15), equals('DataLossException'));
      expect(grpcCodeToExceptionName(16), equals('UnauthenticatedException'));
    });
  });
}
