abstract class ApiException implements Exception {
  final String message;
  final int? code;

  const ApiException(this.message, [this.code]);

  @override
  String toString() => 'ApiException($code): $message';
}

class InvalidArgumentException extends ApiException {
  const InvalidArgumentException([String? msg]) : super(msg ?? 'Invalid argument', 3);
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([String? msg]) : super(msg ?? 'Unauthenticated', 16);
}

class PermissionDeniedException extends ApiException {
  const PermissionDeniedException([String? msg]) : super(msg ?? 'Permission denied', 7);
}

class NotFoundException extends ApiException {
  const NotFoundException([String? msg]) : super(msg ?? 'Not found', 5);
}

class ResourceExhaustedException extends ApiException {
  const ResourceExhaustedException([String? msg]) : super(msg ?? 'Resource exhausted', 8);
}

class InternalServerException extends ApiException {
  const InternalServerException([String? msg]) : super(msg ?? 'Internal server error', 13);
}

class RpcTimeoutException extends ApiException {
  const RpcTimeoutException([String? msg]) : super(msg ?? 'Deadline exceeded', 4);
}

class CancelledException extends ApiException {
  const CancelledException([String? msg]) : super(msg ?? 'Cancelled', 1);
}

class UnknownException extends ApiException {
  const UnknownException([String? msg]) : super(msg ?? 'Unknown', 2);
}

class AlreadyExistsException extends ApiException {
  const AlreadyExistsException([String? msg]) : super(msg ?? 'Already exists', 6);
}

class AbortedException extends ApiException {
  const AbortedException([String? msg]) : super(msg ?? 'Aborted', 10);
}

class OutOfRangeException extends ApiException {
  const OutOfRangeException([String? msg]) : super(msg ?? 'Out of range', 11);
}

class UnimplementedException extends ApiException {
  const UnimplementedException([String? msg]) : super(msg ?? 'Unimplemented', 12);
}

class UnavailableException extends ApiException {
  const UnavailableException([String? msg]) : super(msg ?? 'Unavailable', 14);
}

class DataLossException extends ApiException {
  const DataLossException([String? msg]) : super(msg ?? 'Data loss', 15);
}

class FailedPreconditionException extends ApiException {
  const FailedPreconditionException([String? msg]) : super(msg ?? 'Failed precondition', 9);
}
