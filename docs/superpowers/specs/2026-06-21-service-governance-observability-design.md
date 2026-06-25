---
comet_change: service-governance-observability
role: technical-design
canonical_spec: openspec
archived-with: 2026-06-25-service-governance-observability
status: final
---

# Service Governance and Observability Design

## Context

`protoc-gen-dart-unified` 需要提供健壮的客户端服务治理与可观测性能力。这要求运行时（`runtime`）提供统一的拦截器接口、指数退避重试逻辑、统一的取消与超时机制，以及 W3C Traceparent 链路追踪注入，且无论底层使用 HTTP/Dio 还是 gRPC，对业务侧的使用体验完全一致。

## Goals / Non-Goals

**Goals:**
- **统一拦截器签名**：修改 `RpcInterceptor` 签名，允许在调用链中访问并修改 `request` 与 `RpcCallOptions`。
- **自动重试机制**：实现带有指数退避与随机抖动的自动重试机制。
- **统一取消与超时**：定义 `RpcCancelToken`，并在 `HttpTransport` 与 `GrpcTransport` 层中实现取消与超时条件的统一适配映射。
- **Traceparent 注入**：默认支持 W3C 标准 `traceparent` 头部的生成与注入。

**Non-Goals:**
- 不支持流式調用（Server/Client Streaming）的自动重试。

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
  RpcCallOptions options,
  List<RpcInterceptor> interceptors,
  Future<T> Function(Object req, RpcCallOptions opts) finalCall,
) {
  Future<T> next(int index, Object currentReq, RpcCallOptions currentOpts) {
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

- **[gRPC 异步取消时效性]**：gRPC 请求的取消可能具有异步性。我们需要在集成测试中覆盖拦截器内部取消、网络发起前取消以及网络传输中取消等场景。
