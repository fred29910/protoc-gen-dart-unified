/// gRPC canonical code to HTTP status code mapping.
/// Mirrors grpc-gateway's `HTTPStatusFromCode`.
const int httpStatusOk = 200;
const int httpStatusBadRequest = 400;
const int httpStatusUnauthorized = 401;
const int httpStatusForbidden = 403;
const int httpStatusNotFound = 404;
const int httpStatusConflict = 409;
const int httpStatusTooManyRequests = 429;
const int httpStatusInternalServerError = 500;
const int httpStatusNotImplemented = 501;
const int httpStatusServiceUnavailable = 503;
const int httpStatusGatewayTimeout = 504;

/// Maps gRPC canonical codes to HTTP status codes.
/// Covers all 17 canonical codes.
int grpcCodeToHttpStatus(int grpcCode) {
  return switch (grpcCode) {
    0 => httpStatusOk,                    // OK
    1 => httpStatusInternalServerError,   // CANCELLED
    2 => httpStatusInternalServerError,   // UNKNOWN
    3 => httpStatusBadRequest,            // INVALID_ARGUMENT
    4 => httpStatusGatewayTimeout,        // DEADLINE_EXCEEDED
    5 => httpStatusNotFound,              // NOT_FOUND
    6 => httpStatusConflict,              // ALREADY_EXISTS
    7 => httpStatusForbidden,             // PERMISSION_DENIED
    9 => httpStatusBadRequest,            // FAILED_PRECONDITION
    10 => httpStatusConflict,             // ABORTED
    11 => httpStatusBadRequest,           // OUT_OF_RANGE
    12 => httpStatusNotImplemented,       // UNIMPLEMENTED
    13 => httpStatusInternalServerError,   // INTERNAL
    14 => httpStatusServiceUnavailable,   // UNAVAILABLE
    15 => httpStatusInternalServerError,   // DATA_LOSS
    16 => httpStatusUnauthorized,         // UNAUTHENTICATED
    _ => httpStatusInternalServerError,
  };
}

/// Maps gRPC canonical code to the corresponding ApiException type name.
String grpcCodeToExceptionName(int grpcCode) {
  return switch (grpcCode) {
    1 => 'CancelledException',
    2 => 'UnknownException',
    3 => 'InvalidArgumentException',
    4 => 'RpcTimeoutException',
    5 => 'NotFoundException',
    6 => 'AlreadyExistsException',
    7 => 'PermissionDeniedException',
    9 => 'FailedPreconditionException',
    10 => 'AbortedException',
    11 => 'OutOfRangeException',
    12 => 'UnimplementedException',
    13 => 'InternalServerException',
    14 => 'UnavailableException',
    15 => 'DataLossException',
    16 => 'UnauthenticatedException',
    _ => 'InternalServerException',
  };
}
