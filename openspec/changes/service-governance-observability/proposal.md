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
