## Why

纯 gRPC 服务（无 `google.api.http` 注解）生成的 `*_service.dart` 会无条件 `import '../{proto}.pbgrpc.dart'`，该 import 非条件导入、不区分平台 → Web 编译时引入 `grpc`/`dart:io`，构建失败。根因有二：(1) `service_generator.dart` 为纯 gRPC service 生成静态 pbgrpc import；(2) 生成的单文件 `unified_runtime.dart` 模板把 `GrpcTransport` 实现（依赖 `grpc`/`dart:io`）直接写在模板内，Web 必然编译进该代码。运行时层的条件导入（`transport_factory.dart`）已正确隔离，但 service 文件层与生成 runtime 层仍有泄漏。这违反了既有 `transport-selection` spec 中「Conditional import split」要求。

## What Changes

- **BREAKING**: `service_generator.dart` 不再为纯 gRPC service 生成 `import '../{proto}.pbgrpc.dart'`，生成的 `Unified<Service>` 不再持有 `_grpcClient` 字段，统一通过 `_transport`（由 `createTransport` 返回）发起 unary/streaming 调用。
- **BREAKING**: 生成的 `unified_runtime.dart` 单文件模板删除 `GrpcTransport` 实现类，仅保留 `GrpcClient` 抽象接口与 `createTransport` 工厂函数签名；`GrpcTransport` 实现外置到已条件导入隔离的 `transport_native.dart`（native-only 编译单元）。
- `transport_native.dart` 的 `GrpcTransport` 完善：经 `executeWithInterceptors` 接入拦截器链；`RpcCallOptions.headers` 透传为 gRPC metadata；`timeout` 桥接；`RpcCancelToken` 桥接到 `ResponseFuture.cancel`；`GrpcError` → `ApiException` 映射。
- 新增 `*ServiceClient → GrpcClient` 适配器（native-only），由 `ApiSdk` 构造时接入 `createTransport`。
- Web 平台对纯 gRPC 服务明确报错（非静默打包失败）+ 文档声明。
- 新增 gRPC-only fixture 与 golden/单测覆盖。

## Capabilities

### New Capabilities

- `web-grpc-build-isolation`: 确保 Web 编译产物不含 `grpc`/`dart:io` 依赖的编译期隔离机制（service 文件去 pbgrpc import + 生成 runtime 模板去 GrpcTransport 实现）。

### Modified Capabilities

- `transport-selection`: 扩展「Conditional import split」要求 —— 生成的 `unified_runtime.dart` 单文件必须不含任何 gRPC 实现代码，gRPC 相关实现仅存在于 native 条件导入编译单元。
- `grpc-code-generation`: 更新「gRPC transport delegation」要求 —— `Unified<Service>` 经 `_transport` 统一调用（不再直接引用 `_grpcClient` / `*ServiceClient`），`GrpcTransport` 实现位于 native-only 模块并完整接入拦截器链与 options 透传。

## Impact

- 受影响代码：`lib/src/generators/service_generator.dart`、`lib/src/generators/runtime_inline_generator.dart`、`lib/src/runtime/transport_native.dart`、`lib/src/runtime/transport_factory.dart`、`lib/src/runtime/transport_web.dart`
- 受影响 API：生成的 `Unified<Service>` 构造签名变化（移除 `grpcClient` 参数）；`ApiSdk` 构造需接收 `*ServiceClient` 并经适配器转为 `GrpcClient`
- 破坏性变更：所有存量生成代码需重新生成（一次性）；`docs/usage.md` 补充 Web 纯 gRPC 限制说明
- 依赖：不引入新依赖；`grpc`/`dart:io` 仍仅存在于 native 编译单元
