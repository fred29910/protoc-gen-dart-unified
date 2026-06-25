# Comet Design Handoff

- Change: service-governance-observability
- Phase: design
- Mode: compact
- Context hash: 27cf80177d5f7d2929a3c4d3f6e77b741c32d23d4c7c3f48b7ae7d633cf1f8e0

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/service-governance-observability/proposal.md

- Source: openspec/changes/service-governance-observability/proposal.md
- Lines: 1-22
- SHA256: 0492ee7a19cec94b5a152ece4b3b32a6c1e5554a85893260099c950139348f05

```md
## Why

面向 Flutter 全平台的 RPC SDK 需要具备基本的生产级服务治理和观测能力。当前实现的 MVP 骨架仅支持最基础的 Unary 调用和异构错误映射，缺少拦截器、请求重试、超时控制、主动取消以及分布式链路追踪 (Traceparent) 等高可用和可观测性组件。本变更为 SDK 引入上述能力，提升其在复杂微服务系统中的稳定性和可维护性。

## What Changes

- **拦截器支持**：定义统一的 `RpcInterceptor` 接口并集成到 HTTP 与 gRPC 传输层，允许在请求前后执行自定义逻辑，如日志记录或认证注入。
- **自动重试机制**：实现带有指数退避与随机抖动算法的重试机制，对特定的暂时性失败错误码进行自动重试。
- **超时与取消机制**：为 `RpcCallOptions` 引入统一的超时及取消 Token 控制，使 HTTP (Dio CancelToken) 与 gRPC (ResponseFuture.cancel) 表现一致。
- **Traceparent 链路透传**：内置对 W3C 标准 `traceparent` 头部的生成与注入逻辑，无缝支持分布式链路追踪。

## Capabilities

### New Capabilities
- `service-governance-observability`: 引入服务治理与观测机制，包括统一拦截器、自动重试、统一超时/取消以及 W3C traceparent 注入。

### Modified Capabilities

## Impact

- 核心运行时包 (runtime)：新增并扩展拦截器、取消、重试、可观测性相关数据结构与接口，升级 `ClientOptions`, `RpcCallOptions`, `Transport` 及其实现类。
- 生成的客户端 SDK 代码：在生成的 facade 及具体服务代理中，需要能正确透传 `RpcCallOptions` 并在客户端生命周期中挂载拦截器。
```

## openspec/changes/service-governance-observability/design.md

- Source: openspec/changes/service-governance-observability/design.md
- Lines: 1-56
- SHA256: 79710aac775b1f63e3614f4249b24540f096e007ae2a232a171cd46079a77720

```md
## Context

`protoc-gen-dart-unified` 需要支持健壮的服务治理与观测能力。这要求运行时组件（`runtime`）提供一套统一的拦截器接口、指数退避重试逻辑、统一的取消与超时机制，以及 W3C Traceparent 分布式追踪注入，确保无论底层使用 HTTP 还是 gRPC 传输，对业务侧的体验是完全一致的。

## Goals / Non-Goals

**Goals:**
- **统一拦截器签名**：修改 `RpcInterceptor` 签名，使其能够同时访问并修改 `request` 与 `RpcCallOptions`。
- **指数退避重试**：提供 `RetryPolicy` 配置，并在调用中支持指数退避与随机抖动。
- **统一超时与取消**：定义 `RpcCancelToken` 并在底层 HTTP/Dio 及 gRPC 传输中实现取消动作的统一映射。
- **Traceparent 注入**：为每个请求默认生成并附加 `traceparent` 头。

**Non-Goals:**
- 本次设计不包含流式调用的重试（仅针对 Unary 调用的重试）。

## Decisions

### 1. 拦截器签名重构
为了使拦截器能向后传递修改后的 `RpcCallOptions`（例如 AuthInterceptor 注入 HTTP Header / gRPC Metadata），我们将 `RpcInterceptor` 重构为：
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
并且在 `ClientOptions` 中增加 `List<RpcInterceptor> interceptors` 注册项。

### 2. 统一取消 Token 设计
定义 `RpcCancelToken` 作为取消事件的发布者：
- **HTTP/Dio** 适配：通过 `CancelToken` 监听 `RpcCancelToken` 并在取消时调用 `dio.CancelToken.cancel()`。
- **gRPC** 适配：由于 Dart gRPC 原生 `ResponseFuture` 返回后才能取消，我们在 `GrpcTransport` 发起调用后，将返回的 `ResponseFuture.cancel()` 作为监听器注册到 `RpcCancelToken` 上。

### 3. 指数退避重试与抖动算法
设计 `RetryPolicy` 类，并实现通用的重试包装函数：
```dart
Future<T> withRetry<T>(
  Future<T> Function() fn,
  RetryPolicy policy,
  bool Function(Exception) shouldRetry,
)
```
重试判断逻辑基于异构异常转换后的 `ApiException` 中的 gRPC Code（仅在 `UNAVAILABLE`, `RESOURCE_EXHAUSTED` 等状态下重试）。

### 4. Traceparent 头注入
默认在 `RpcCallOptions` 中生成 `traceparent` 并写入 `headers`。
- W3C 格式：`00-${traceId}-${spanId}-01`。
- 如果用户未在 `ClientOptions` 中关闭 tracing，则每次请求自动生成一个 traceparent 字符串。

## Risks / Trade-offs

- **[gRPC 异步取消时效性]** → gRPC 请求在真正连接建立前如果被取消，需要确保底层的 `ResponseFuture.cancel()` 正确中断连接，这由官方 `grpc` 库保证。我们将在集成测试中验证。
```

## openspec/changes/service-governance-observability/tasks.md

- Source: openspec/changes/service-governance-observability/tasks.md
- Lines: 1-18
- SHA256: 4b1427892cbe1af592b56905ea396f4faa6cb1d183210cc268d74dee117b70bb

```md
## 1. 基础治理组件定义与实现

- [ ] 1.1 重构 `RpcInterceptor` 签名，支持传入并更新 `RpcCallOptions`
- [ ] 1.2 实现 `RpcCancelToken` 并支持注册取消监听回调
- [ ] 1.3 实现 `RetryPolicy` 结构与带指数退避和随机抖动算法的 `withRetry` 包装器
- [ ] 1.4 实现 W3C `traceparent` 的生成和注入工具函数

## 2. 传输层与选项集成

- [ ] 2.1 升级 `ClientOptions` 和 `RpcCallOptions` 以支持拦截器、取消 Token 和 Tracing 开关
- [ ] 2.2 在 `HttpTransport` 中实现拦截器执行链、Dio `CancelToken` 绑定和 `traceparent` 注入
- [ ] 2.3 在 `GrpcTransport` 中实现拦截器执行链、gRPC `ResponseFuture` 取消绑定和 `traceparent` 注入
- [ ] 2.4 在 `HttpTransport` 和 `GrpcTransport` 中集成 `withRetry` 重试机制

## 3. 生成器适配与端到端验证

- [ ] 3.1 适配 Facade/Client 代码生成器，确保生成的 API 客户端能正确透传 `RpcCallOptions` 并执行拦截器
- [ ] 3.2 编写针对拦截器、自动重试、取消/超时、以及 traceparent 注入的单元与集成测试，确保 100% 验证通过
```

## openspec/changes/service-governance-observability/specs/service-governance-observability/spec.md

- Source: openspec/changes/service-governance-observability/specs/service-governance-observability/spec.md
- Lines: 1-33
- SHA256: c446fc9b3cee60b725c02292b5d90dcbd602fe1c4f9c30b0074a651c44904c24

```md
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
```

