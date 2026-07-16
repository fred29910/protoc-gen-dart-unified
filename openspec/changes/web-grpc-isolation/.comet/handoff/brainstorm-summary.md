# Brainstorm Summary

- Change: web-grpc-isolation
- Date: 2026-07-16

## 确认的技术方案

方案 A（单文件 runtime 模板去 GrpcTransport 实现 + service 生成去 pbgrpc import）：

1. **Generator 层（service_generator.dart）**
   - `_buildDirectives()` 移除 `!_useHttp` 分支的 `import '../{proto}.pbgrpc.dart'`，service 文件仅保留 `unified_runtime.dart` + `*.pb.dart`
   - `_buildUnifiedImpl()` 移除 `_grpcClient` 字段与 `grpcClient` 构造参数；`Unified<Service>` 仅持有 `_transport` + `_interceptors`
   - `_buildGrpcUnaryCall` / `_buildGrpcServerStreamBody` 改为 `_transport.unaryCall` / `_transport.serverStream`，携带 `ctx.options`
   - `_buildApiSdk()` 接收用户 `*ServiceClient`，经泛型适配器转为 `GrpcClient` 后传给 `createTransport`；HTTP 服务传 `grpcClient: null`

2. **Runtime 模板层（runtime_inline_generator.dart）**
   - 删除模板中的 `GrpcTransport` 类（原 617-662 行），保留 abstract `GrpcClient` + `createTransport` 工厂签名；模板不含 `grpc`/`dart:io` import

3. **Runtime 实现层（transport_native.dart，native-only）**
   - `GrpcTransport` 完善：`unaryCall`/`serverStream` 经 `executeWithInterceptors` 套拦截器链
   - `_rawGrpcUnaryCall` / `_rawGrpcServerStream` 将 `RpcCallOptions` 映射为 gRPC `CallOptions`：`headers` → metadata，`timeout` → `CallOption.timeout`，`cancelToken` → `RpcCancelToken.onCancel` 回调桥接到 `ResponseFuture.cancel()`
   - `GrpcError` → `ApiException`（按 gRPC canonical code）
   - 新增泛型适配器类（如 `GrpcClientAdapter implements GrpcClient`），`unaryCall`/`serverStream` 委托到具体 `*ServiceClient`

4. **Web 失败检测（transport_web.dart）**
   - `createTransport` 的 web 分支检测 `grpcClient != null` 时显式 `throw UnsupportedError('Web 不支持纯 gRPC 服务...')`

## 关键取舍与风险

- 单文件模板与条件导入冲突 → 采用方案 A，gRPC 实现外置 native-only 模块
- HTTP golden 漂移 → `UPDATE_GOLDENS=1` 同步 + CI 门禁
- 适配器耦合 `protoc-gen-dart` `*ServiceClient` API → 仅依赖 `unaryCall`/`serverStream` 标准签名，最小化耦合
- 破坏性变更 → 一次性重新生成 + `docs/usage.md` 迁移说明
- Web gRPC 取消桥接 → `onCancel` 回调桥接 `ResponseFuture.cancel()`，native-only 不污染 web

## 测试策略

- 新增 gRPC-only fixture `test/fixtures/echo.proto`（无 `google.api.http`）
- 集成测试：生成 `echo_service.dart` 断言无 `import '*.pbgrpc.dart'`、`UnifiedEcho` 无 `_grpcClient` 字段、方法体调用 `_transport.unaryCall`
- `transport_native_test.dart`：用 `TestGrpcClient` 双验证 `GrpcTransport` 委托 + 错误映射
- Web 隔离验证（任务 3.4）：**静态文本断言 + `dart analyze`** —— 解析生成的 `unified_runtime.dart` 断言不含 `grpc`/`dart:io` import 与 `GrpcTransport` 类定义（轻量、无需编译）
- `UPDATE_GOLDENS=1` 同步 golden + 扩展 gRPC-only 场景
- `dart test` + `dart analyze --fatal-infos` 全绿

## Spec Patch

无（现有 delta spec 已覆盖全部验收场景，无需补充）
