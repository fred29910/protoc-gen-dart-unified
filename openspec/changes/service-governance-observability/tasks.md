## 已完成 ✅（无需额外工作）

- [x] 统一 `RpcInterceptor` 接口（`InterceptorContext` + `proceed` 回调）
- [x] `InterceptorContext` 支持 `copyWith` 传递修改后的 request/options
- [x] `RetryPolicy` 指数退避 + 随机抖动算法
- [x] `RetryInterceptor` 基于 `ApiException.code` 的重试判断
- [x] `TracingInterceptor` W3C traceparent 生成与注入
- [x] `AuthInterceptor` Token 注入
- [x] `LoggingInterceptor` 日志记录
- [x] `SseParser` Server-Sent Events 解析
- [x] `ApiException` 全 17 个 canonical code 异常体系
- [x] `http_status_mapping` gRPC code ↔ HTTP status 双向映射

## A. 运行时核心集成

- [ ] A1. 实现 `RpcCancelToken`（取消事件发布者 + HTTP/Dio + gRPC 适配）
- [ ] A2. 实现 `withRetry` 便捷包装器（顶层 API 函数）
- [ ] A3. 升级 `ClientOptions`（+interceptors, retryPolicy, tracingEnabled, autoRetryEnabled）
- [ ] A4. 在 `Transport` 基类实现 `executeWithInterceptors` 递归闭包
- [ ] A5. `HttpTransport` 集成拦截器链 + `RpcCancelToken` 绑定 + `withRetry`
- [ ] A6. `GrpcTransport` 集成拦截器链 + `ResponseFuture.cancel` 绑定

## B. 生成器适配

- [ ] B1. 升级 `ServiceGenerator` 生成的 `ApiSdk`，透传 `interceptors` / `retryPolicy` 配置
- [ ] B2. 在生成代码中默认挂载 `TracingInterceptor`（如果 tracingEnabled）
- [ ] B3. 在生成代码中自动挂载 `RetryInterceptor`（如果 autoRetryEnabled）

## C. 测试

- [ ] C1. `RpcCancelToken` 单元测试
- [ ] C2. `withRetry` 单元测试（指数退避 + 抖动验证）
- [ ] C3. `executeWithInterceptors` 单元测试（多拦截器链式执行顺序）
- [ ] C4. `HttpTransport` 集成测试（拦截器 + 重试 + 取消）
- [ ] C5. 生成器集成测试（生成代码包含拦截器链挂载）
