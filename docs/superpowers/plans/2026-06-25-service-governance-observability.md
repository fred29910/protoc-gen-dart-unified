---
change: service-governance-observability
design-doc: docs/superpowers/specs/2026-06-21-service-governance-observability-design.md
base-ref: a342d23bf821e2baceb254ebd43b0a341debfe92
---

# Service Governance & Observability — 实施计划

## 已完成项（参考 tasks.md [x] 标记）

- 统一 RpcInterceptor 接口 + InterceptorContext copyWith
- RetryPolicy 指数退避 + 随机抖动
- RetryInterceptor / TracingInterceptor / AuthInterceptor / LoggingInterceptor
- SseParser / ApiException 17 canonical code / http_status_mapping
- RpcCancelToken (A1) / withRetry (A2) / ClientOptions 升级 (A3) / executeWithInterceptors (A4)

## 剩余任务

### Phase 1: Transport 层集成 (A5, A6)

#### Task A5: HttpTransport 集成拦截器链 + RpcCancelToken 绑定

**文件**: `lib/src/runtime/transport_web.dart`, `lib/src/runtime/transport_native.dart`

**目标**: HttpTransport 构造时接收 `List<RpcInterceptor>`，在 `unaryCall` 中通过 `executeWithInterceptors` 执行拦截器链，绑定 `RpcCancelToken` 到 Dio `CancelToken`。

**实现要点**:
1. HttpTransport 构造函数增加 `interceptors` 参数（默认 `const []`）
2. `unaryCall` 中，如果 `options?.cancelToken` 不为 null，创建 Dio `CancelToken` 并监听 RpcCancelToken 的 cancel 回调
3. 将 Dio CancelToken 传入 Dio Options
4. 在调用前通过 `executeWithInterceptors` 包装核心调用

**适配器映射**:
- RpcCancelToken.cancel() → Dio CancelToken.cancel()
- RpcCancelToken.onCancel() → 监听 Dio CancelToken 的 CancelledException

#### Task A6: GrpcTransport 集成拦截器链 + ResponseFuture.cancel 绑定

**文件**: `lib/src/runtime/transport_native.dart`

**目标**: GrpcTransport 构造时接收 `List<RpcInterceptor>`，在 `unaryCall` 中通过 `executeWithInterceptors` 执行拦截器链，绑定 `RpcCancelToken` 到 `ResponseFuture.cancel()`。

**实现要点**:
1. GrpcTransport 构造函数增加 `interceptors` 参数
2. `unaryCall` 中，如果 `options?.cancelToken` 不为 null，在调用后监听 cancel 事件
3. 将 ResponseFuture 的 cancel 代理到 RpcCancelToken

### Phase 2: 生成器适配 (B1-B3)

#### Task B1: 升级 ApiSdk 透传配置

**文件**: `lib/src/generators/service_generator.dart`

**目标**: 生成的 `ApiSdk` 从 `ClientOptions` 读取 `interceptors`、`retryPolicy`、`tracingEnabled`、`autoRetryEnabled`，通过 `buildInterceptorChain()` 构建完整拦截器链，传递给 `Unified<Service>` 构造函数。

**实现要点**:
1. `_buildApiSdk()` 中，构造函数体改为：
   ```dart
   final chain = options.buildInterceptorChain() + interceptors;
   ```
2. 将 chain 传递给 Unified 构造函数

#### Task B2: 默认挂载 TracingInterceptor

已在 `ClientOptions.buildInterceptorChain()` 中实现（tracingEnabled 时自动 prepend TracingInterceptor）。需确认生成代码正确传递 `tracingEnabled`。

#### Task B3: 自动挂载 RetryInterceptor

已在 `ClientOptions.buildInterceptorChain()` 中实现（autoRetryEnabled && retryPolicy != null 时自动 append RetryInterceptor）。需确认生成代码正确传递 `autoRetryEnabled`。

### Phase 3: 测试 (C1-C5)

#### Task C1: RpcCancelToken 单元测试
- cancel() 触发 isCancelled = true
- onCancel() 回调在 cancel() 后触发
- throwIfCancelled() 抛出 RpcCancelledException
- 重复 cancel() 不重复触发回调

#### Task C2: withRetry 单元测试
- 指数退避延迟验证
- 随机抖动范围验证
- shouldRetry 自定义谓词
- 达到 maxAttempts 后 rethrow
- 首次成功不重试

#### Task C3: executeWithInterceptors 单元测试
- 空拦截器列表直接调用 finalCall
- 多拦截器按顺序执行
- 拦截器可修改 request/options 传递给下一个
- 拦截器可短路调用链

#### Task C4: HttpTransport 集成测试
- 拦截器链正确执行
- RpcCancelToken 取消请求
- withRetry 重试失败请求

#### Task C5: 生成器集成测试
- 生成代码包含 interceptor chain 挂载
- 生成代码正确传递 ClientOptions 配置

## 执行顺序

```
A5 → A6 → B1 → 确认 B2/B3 → C1 → C2 → C3 → C4 → C5
```

A5/A6 可并行（web 和 native 各自独立）。
C1-C3 可并行。
