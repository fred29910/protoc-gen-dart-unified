# Brainstorm Summary

- Change: service-governance-observability
- Date: 2026-06-21

## 确认的技术方案

1. **拦截器签名与链式调度**：重构 `RpcInterceptor` 签名，支持传入并更新 `RpcCallOptions`；通过在 `Transport` 层定义通用递归执行入口实现拦截器链。
2. **统一取消 Token (`RpcCancelToken`)**：实现统一的 `RpcCancelToken`；针对 HTTP (Dio) 使用 `CancelToken` 绑定，针对 gRPC 使用 `ResponseFuture.cancel()` 绑定。
3. **内置治理拦截器**：
   - `RetryInterceptor`：支持配置最大尝试次数、初始延迟、最大延迟、乘数、抖动，并在 `UNAVAILABLE` 等特定错误下自动退避重试。
   - `TracingInterceptor`：在 Tracing 启用时，自动为每个请求生成 W3C `traceparent` 头。
4. **`ClientOptions` 扩展**：支持配置拦截器列表、重试策略及 Tracing 开启状态，并在初始化时自动编排它们。

## 关键取舍与风险

- gRPC 的取消必须在 `ResponseFuture` 返回后完成监听绑定，测试时必须覆盖连接前、连接中的异步取消用例。

## 测试策略

- 针对各内置拦截器（Auth、Retry、Tracing、Cancel/Timeout）编写专用的运行时单元与集成测试。

## Spec Patch

无
