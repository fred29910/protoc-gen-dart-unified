# Service Governance and Observability Design

## Context

`protoc-gen-dart-unified` 需要提供健壮的客户端服务治理与可观测性能力。这要求运行时（`runtime`）提供统一的拦截器接口、指数退避重试逻辑、统一的取消与超时机制，以及 W3C Traceparent 链路追踪注入，且无论底层使用 HTTP/Dio 还是 gRPC，对业务侧的使用体验完全一致。

## Goals / Non-Goals

|**Goals:**
|- **统一拦截器签名**：修改 `RpcInterceptor` 签名，允许在调用链中访问并修改 `request` 与 `RpcCallOptions`。
|- **自动重试机制**：实现带有指数退避与随机抖动的自动重试机制。
|- **统一取消与超时**：定义 `RpcCancelToken`，并在 `HttpTransport` 与 `GrpcTransport` 层中实现取消与超时条件的统一适配映射。
|- **Traceparent 注入**：默认支持 W3C 标准 `traceparent` 头部的生成与注入。

|**Non-Goals:**
|- 不支持流式調用（Server/Client Streaming）的自动重试。

## Decisions

### 1. 拦截器接口与拦截器链设计
重构 `RpcInterceptor` 接口为链式传递结构，允许在调用前后修改请求与选项：

```dart
abstract class RpcInterceptor {
  Future<T> intercept<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions options,
    Future<T> Function(Object req, RpcCallOptions opts) proceed,
  );
}
```

在 `Transport` 基类中使用递归闭包方式执行拦截器链：

```dart
Future<T> executeWithInterceptors<T>(
  String serviceName,
  String methodName,
  Object request,
  RpcCallOptions? options,
  List<RpcInterceptor> interceptors,
  Future<T> Function(Object req, RpcCallOptions? opts) finalCall,
) {
  Future<T> next(int index, Object currentReq, RpcCallOptions? currentOpts) {
    if (index >= interceptors.length) {
      return finalCall(currentReq, currentOpts);
    }
    return interceptors[index].intercept(
      serviceName,
      methodName,
      currentReq,
      currentOpts,
      (nextReq, nextOpts) => next(index + 1, nextReq, nextOpts),
    );
  }
  return next(0, request, options);
}
```

### 2. 统一取消 Token 桥接设计
实现自定义 `RpcCancelToken`，并在不同 Transport 中进行适配：
- **HTTP / Dio**：绑定到 Dio 的 `CancelToken`。
- **gRPC**：对 Stub 调用的返回对象 `ResponseFuture` 执行 `cancel()`。
- 超时通过配置底层传输框架的原生超时来实现（Dio Options 里的超时及 gRPC Stub Options 中的 timeout）。

### 3. 内置重试拦截器 (`RetryInterceptor`)
定义 `RetryPolicy` 并使用 `RetryInterceptor` 执行指数退避与随机抖动重试。默认仅针对暂时性失败（gRPC Code: `14 (UNAVAILABLE)` 等）进行重试。
重试算法：
$$\text{Delay} = \min(\text{maxDelay}, \text{initialDelay} \times \text{multiplier}^{\text{attempt}-1}) \pm \text{Jitter}$$

### 4. 内置 Traceparent 拦截器 (`TracingInterceptor`)
在 Tracing 启用时，自动为每个请求生成 W3C `traceparent` 头，注入到 HTTP headers / gRPC metadata 中：
`00-${traceId}-${spanId}-01`

### 5. `ClientOptions` 与内置拦截器默认装配
升级 `ClientOptions`，允许配置拦截器列表、重试策略及 Tracing 开启状态。在客户端初始化时按顺序编排拦截器链：`TracingInterceptor` -> 用户自定义拦截器 -> `RetryInterceptor`。

## Risks / Trade-offs

|- **[gRPC 异步取消时效性]**：gRPC 请求的取消可能具有异步性。我们需要在集成测试中覆盖拦截器内部取消、网络发起前取消以及网络传输中取消等场景。

## ADDED Requirements

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

### Requirement: withRetry Top-Level API

The system SHALL provide `withRetry<T>(Future<T> Function() fn, RetryPolicy policy, {bool Function(Object error)? shouldRetry})` as a convenience API for wrapping any async function with retry logic. The function SHALL be retried according to the policy when errors match `shouldRetry` (defaults to transient errors).

#### Scenario: withRetry succeeds after transient failure
- **WHEN** a function fails with UNAVAILABLE (code 14) first attempt, succeeds second
- **THEN** `withRetry` retries after calculated backoff and returns the result

#### Scenario: withRetry respects max attempts
- **WHEN** a function fails up to maxAttempts (e.g., 3) without success
- **THEN** `withRetry` rethrows the last error

### Requirement: SSE Stream Parsing Specification

The system SHALL parse SSE streams following the WHATWG SSE spec. Requirements:
- Split events on double newlines (\n\n, \r\n\r\n, \r\r)
- Extract `data:` fields from each event
- Join multi-line data as single string with \n
- Ignore comment lines (prefix :), event:, id:, retry:

#### Scenario: SSE data line yielded
- **WHEN** stream contains `data: hello\r\n\r\n`
- **THEN** parser yields `"hello"`

#### Scenario: Multi-line data joined
- **WHEN** stream contains `data: line1\n data: line2\n\n`
- **THEN** parser yields `"line1\nline2"`

### Requirement: Canonical Exception Hierarchy

The system SHALL define `ApiException` with 17 gRPC canonical codes. New exceptions:
- `RpcTimeoutException` (code 4): "Deadline exceeded"
- `CancelledException` (code 1): "Cancelled"  
- `RpcCancelledException` (code 1): "RpcCancelledException with reason"

#### Scenario: Exception carries correct gRPC code
- **WHEN** `RpcTimeoutException("test")` is instantiated
- **THEN** it throws with code 4

#### Scenario: RpcCancelledException thrown by token
- **WHEN** `RpcCancelToken` is cancelled and user calls `throwIfCancelled()`
- **THEN** it throws `RpcCancelledException` with the provided reason

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
