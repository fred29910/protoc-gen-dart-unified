## ADDED Requirements

### Requirement: Unified Interceptor Support
The system SHALL define the `RpcInterceptor` interface and allow registering interceptors in `ClientOptions`. Both HTTP and gRPC transport layers MUST execute these interceptors sequentially for all unary and streaming RPC calls.

#### Scenario: AuthInterceptor inserts token
- **WHEN** a client initiates an RPC call with an AuthInterceptor registered
- **THEN** both HTTP headers and gRPC metadata contain the injected token

### Requirement: Exponential Backoff Retry with Jitter
The system SHALL support automatic retries for transient failures. It MUST support configuring max attempts, initial delay, multiplier, and random jitter. It SHALL retry only on specific transient gRPC error codes (such as UNAVAILABLE or RESOURCE_EXHAUSTED).

#### Scenario: Retry on transient error succeeds
- **WHEN** an RPC call fails on the first attempt with UNAVAILABLE but succeeds on the second attempt
- **THEN** the transport retries after the calculated backoff delay and returns the successful response

### Requirement: Unified Timeout and Cancellation
The system SHALL support timeouts and cancellation via `RpcCallOptions` and a dedicated `RpcCancelToken`. It MUST map timeout conditions to `RpcTimeoutException` and cancellations to `CancelledException`.

#### Scenario: Request times out
- **WHEN** an RPC call takes longer than the timeout duration specified in `RpcCallOptions`
- **THEN** the transport aborts the execution and throws `RpcTimeoutException`

#### Scenario: Request is cancelled manually
- **WHEN** a user invokes `RpcCancelToken.cancel()` on a token passed into `RpcCallOptions` during an active call
- **THEN** the transport aborts the execution and throws `CancelledException`

### Requirement: W3C Traceparent Header Injection
The system SHALL support automatic generation and injection of W3C-compliant `traceparent` tracing headers (`00-{trace_id}-{span_id}-01`) into HTTP headers and gRPC metadata for all outgoing requests when tracing is enabled.

#### Scenario: Traceparent header present
- **WHEN** a client initiates an RPC call
- **THEN** the outgoing HTTP request headers or gRPC metadata contain a valid W3C `traceparent` header
