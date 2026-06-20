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
