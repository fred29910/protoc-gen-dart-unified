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
