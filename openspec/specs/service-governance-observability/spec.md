# service-governance-observability Specification

## Purpose
TBD - created by archiving change service-governance-observability. Update Purpose after archive.
## Requirements
### Requirement: Unified Interceptor Support

The system SHALL define the `RpcInterceptor` interface and allow registering interceptors in `ClientOptions`. Both HTTP and gRPC transport layers MUST execute these interceptors sequentially for all unary and streaming RPC calls.

#### Scenario: RpcInterceptor interface definition
- **WHEN** the system defines `RpcInterceptor`
- **THEN** it SHALL have `intercept<T>` method with serviceName, methodName, request, options, and proceed callback parameters

### Requirement: RpcCancelToken Interface

The system SHALL provide an `RpcCancelToken` class for cooperative cancellation. It MUST support:
- Registration of callbacks via `onCancel()`
- Triggering all callbacks via `cancel([reason])`
- Checking cancellation status via `isCancelled`
- Accessing cancellation reason via `cancelledReason`
- Throwing `RpcCancelledException` via `throwIfCancelled()`

#### Scenario: RpcCancelToken basic usage
- **WHEN** a user creates `RpcCancelToken token`
- **THEN** `token.isCancelled` is `false` initially
- **WHEN** the user calls `token.cancel("user requested")`
- **THEN** `token.isCancelled` becomes `true`, `token.cancelledReason` is `"user requested"`, and all registered callbacks are invoked

### Requirement: Unified Timeout and Cancellation Mapping

The system SHALL map timeout conditions to `RpcTimeoutException` (gRPC code 4) and cancellations to `CancelledException` (gRPC code 1). Timeout errors SHALL be raised when `RpcCallOptions.timeout` expires and the underlying transport fails to complete the call within the deadline.

#### Scenario: Timeout triggers RpcTimeoutException
- **WHEN** `RpcCallOptions(timeout: const Duration(seconds: 5))` is set and the call exceeds 5 seconds
- **THEN** the transport throws `RpcTimeoutException` with message "Deadline exceeded"

#### Scenario: Cancellation triggers CancelledException
- **WHEN** `RpcCallOptions` includes `cancelToken` and user calls `cancelToken.cancel("aborted")`
- **THEN** the transport throws `CancelledException` with message "Aborted"

The interceptor chain SHALL be executed in the following order:
1. `TracingInterceptor` (if `tracingEnabled` is true)
2. User-defined interceptors (in the order they were registered in `ClientOptions.interceptors`)
3. `RetryInterceptor` (if `autoRetryEnabled` is true and `retryPolicy` is set)

#### Scenario: AuthInterceptor inserts token
- **WHEN** a client initiates an RPC call with an AuthInterceptor registered
- **THEN** both HTTP headers and gRPC metadata contain the injected token

#### Scenario: Interceptor chain executes in order
- **WHEN** a client has tracing enabled, a custom interceptor, and retry enabled
- **THEN** the tracing header is injected first, the custom interceptor sees the traceparent, and retry wraps the outer call

#### Scenario: Interceptor can modify request and options
- **WHEN** an interceptor calls `proceed` with a modified `InterceptorContext`
- **THEN** subsequent interceptors and the final transport receive the modified request and options

### Requirement: Exponential Backoff Retry with Jitter

The system SHALL support automatic retries for transient failures. It MUST support configuring max attempts, initial delay, multiplier, and random jitter. It SHALL retry only on specific transient gRPC error codes (such as UNAVAILABLE or RESOURCE_EXHAUSTED).

The retry delay SHALL be computed as:
```
delay = min(maxDelay, initialDelay × multiplier^(attempt-1)) ± jitter
```
where `jitter = delay × jitterFactor × (random() × 2 - 1)`.

#### Scenario: Retry on transient error succeeds
- **WHEN** an RPC call fails on the first attempt with UNAVAILABLE but succeeds on the second attempt
- **THEN** the transport retries after the calculated backoff delay and returns the successful response

#### Scenario: Non-transient error is not retried
- **WHEN** an RPC call fails with INVALID_ARGUMENT (code 3)
- **THEN** the error is immediately rethrown without retry

### Requirement: Unified Timeout and Cancellation

The system SHALL support timeouts and cancellation via `RpcCallOptions` and a dedicated `RpcCancelToken`. It MUST map timeout conditions to `RpcTimeoutException` and cancellations to `CancelledException`.

#### Scenario: Request times out
- **WHEN** an RPC call takes longer than the timeout duration specified in `RpcCallOptions`
- **THEN** the transport aborts the execution and throws `RpcTimeoutException`

#### Scenario: Request is cancelled manually
- **WHEN** a user invokes `RpcCancelToken.cancel()` on a token passed into `RpcCallOptions` during an active call
- **THEN** the transport aborts the execution and throws `CancelledException`

#### Scenario: RpcCancelToken bridges to HTTP Dio CancelToken
- **WHEN** a user passes an `RpcCancelToken` via `RpcCallOptions.cancelToken` to an HTTP transport call
- **THEN** the transport bridges the token to Dio's `CancelToken`, and calling `RpcCancelToken.cancel()` causes the Dio request to abort

#### Scenario: RpcCancelToken bridges to gRPC ResponseFuture.cancel
- **WHEN** a user passes an `RpcCancelToken` via `RpcCallOptions.cancelToken` to a gRPC transport call
- **THEN** the transport bridges the token such that calling `RpcCancelToken.cancel()` invokes `ResponseFuture.cancel()`

#### Scenario: Timeout triggers RpcTimeoutException
- **WHEN** `RpcCallOptions.timeout` is set and the underlying transport exceeds the deadline
- **THEN** the transport catches the underlying timeout error and throws `RpcTimeoutException` (gRPC code 4)

### Requirement: W3C Traceparent Header Injection

The system SHALL support automatic generation and injection of W3C-compliant `traceparent` tracing headers (`00-{trace_id}-{span_id}-01`) into HTTP headers and gRPC metadata for all outgoing requests when tracing is enabled.

The `traceparent` header format SHALL be:
```
version-trace-id-parent-id-trace-flags
```
where:
- `version` is always `00`
- `trace-id` is a 32-character hex string
- `parent-id` is a 16-character hex string
- `trace-flags` is always `01` (sampled)

#### Scenario: Traceparent header present
- **WHEN** a client initiates an RPC call
- **THEN** the outgoing HTTP request headers or gRPC metadata contain a valid W3C `traceparent` header

#### Scenario: Traceparent is unique per call
- **WHEN** a client makes multiple RPC calls
- **THEN** each call receives a unique `parent-id` (span ID)

### Requirement: withRetry Top-Level API

The system SHALL provide a `withRetry` top-level function that wraps any async function with retry logic according to a `RetryPolicy`. This function SHALL be available as a convenience API for wrapping arbitrary calls without requiring interceptor setup.

#### Scenario: withRetry succeeds after transient failure
- **WHEN** a function fails with UNAVAILABLE on the first attempt but succeeds on the second
- **THEN** `withRetry` retries according to the policy and returns the successful result

#### Scenario: withRetry respects max attempts
- **WHEN** a function fails on every attempt up to `maxAttempts`
- **THEN** `withRetry` rethrows the last error after exhausting all attempts

### Requirement: ClientOptions Interceptor Chain Assembly

The system SHALL assemble the effective interceptor chain in `ClientOptions.buildInterceptorChain()`. The chain order SHALL be:
1. `TracingInterceptor` (prepended if `tracingEnabled` is true)
2. User-defined interceptors (in registration order)
3. `RetryInterceptor` (appended if `autoRetryEnabled` is true and `retryPolicy` is non-null)

#### Scenario: Default chain includes tracing and retry
- **WHEN** `ClientOptions` is created with default values (`tracingEnabled: true`, `autoRetryEnabled: true`, `retryPolicy` set)
- **THEN** `buildInterceptorChain()` returns `[TracingInterceptor, RetryInterceptor]`

#### Scenario: Custom interceptors are placed in the middle
- **WHEN** `ClientOptions` has `interceptors: [AuthInterceptor(), LoggingInterceptor()]`
- **THEN** `buildInterceptorChain()` returns `[TracingInterceptor, AuthInterceptor, LoggingInterceptor, RetryInterceptor]`

### Requirement: SSE Stream Parsing

The system SHALL provide an `SseParser` that parses Server-Sent Events (SSE) byte streams according to the WHATWG specification. The parser SHALL:
- Split events on double newlines (`\n\n`, `\r\n\r\n`, `\r\r`)
- Extract `data:` field values
- Ignore comments (lines starting with `:`)
- Ignore `event:`, `id:`, and `retry:` fields
- Yield multi-line data as a single string joined by `\n`

#### Scenario: SSE data line is yielded
- **WHEN** the stream contains `data: hello\n\n`
- **THEN** the parser yields `"hello"`

#### Scenario: Multi-line data is joined
- **WHEN** the stream contains `data: line1\ndata: line2\n\n`
- **THEN** the parser yields `"line1\nline2"`

#### Scenario: Comments are ignored
- **WHEN** the stream contains `: heartbeat\n\ndata: hello\n\n`
- **THEN** the parser yields only `"hello"`

### Requirement: Canonical Exception Hierarchy

The system SHALL define an `ApiException` hierarchy covering all 17 gRPC canonical error codes. Each exception type SHALL carry its corresponding gRPC code:

| Exception Class | gRPC Code | Description |
|----------------|-----------|-------------|
| `CancelledException` | 1 | Operation cancelled |
| `UnknownException` | 2 | Unknown error |
| `InvalidArgumentException` | 3 | Invalid argument |
| `RpcTimeoutException` | 4 | Deadline exceeded |
| `NotFoundException` | 5 | Not found |
| `AlreadyExistsException` | 6 | Already exists |
| `PermissionDeniedException` | 7 | Permission denied |
| `ResourceExhaustedException` | 8 | Resource exhausted |
| `FailedPreconditionException` | 9 | Failed precondition |
| `AbortedException` | 10 | Aborted |
| `OutOfRangeException` | 11 | Out of range |
| `UnimplementedException` | 12 | Unimplemented |
| `InternalServerException` | 13 | Internal server error |
| `UnavailableException` | 14 | Unavailable |
| `DataLossException` | 15 | Data loss |
| `UnauthenticatedException` | 16 | Unauthenticated |

Additionally, `RpcCancelledException` SHALL be used internally by `RpcCancelToken` to signal cooperative cancellation within the interceptor chain.

#### Scenario: ApiException carries correct gRPC code
- **WHEN** an `UnavailableException` is thrown
- **THEN** its `code` property returns `14`

#### Scenario: RpcTimeoutException maps to gRPC DEADLINE_EXCEEDED
- **WHEN** a timeout occurs
- **THEN** the thrown exception is `RpcTimeoutException` with code `4`

#### Scenario: RpcCancelledException is thrown by RpcCancelToken
- **WHEN** `RpcCancelToken.throwIfCancelled()` is called after the token is cancelled
- **THEN** it throws `RpcCancelledException` with the cancellation reason

### Requirement: HTTP Status to gRPC Code Mapping

The system SHALL provide bidirectional mapping between HTTP status codes and gRPC canonical codes for error translation in transport layers.

| HTTP Status | gRPC Code | Exception |
|-------------|-----------|-------------|
| 400 | 3 | `InvalidArgumentException` |
| 401 | 16 | `UnauthenticatedException` |
| 403 | 7 | `PermissionDeniedException` |
| 404 | 5 | `NotFoundException` |
| 409 | 6 | `AlreadyExistsException` |
| 422 | 3 | `InvalidArgumentException` |
| 429 | 8 | `ResourceExhaustedException` |
| 500 | 13 | `InternalServerException` |
| 501 | 12 | `UnimplementedException` |
| 502 | 14 | `UnavailableException` |
| 503 | 14 | `UnavailableException` |
| 504 | 4 | `RpcTimeoutException` |

Unmapped status codes SHALL default to gRPC code 2 (`UnknownException`).

#### Scenario: HTTP 503 maps to UNAVAILABLE
- **WHEN** an HTTP transport receives a 503 response
- **THEN** it throws `UnavailableException` with code 14

#### Scenario: HTTP 504 maps to DEADLINE_EXCEEDED
- **WHEN** an HTTP transport receives a 504 response
- **THEN** it throws `RpcTimeoutException` with code 4

#### Scenario: Unknown HTTP status maps to UNKNOWN
- **WHEN** an HTTP transport receives an unmapped status code (e.g. 418)
- **THEN** it throws `UnknownException` with code 2

