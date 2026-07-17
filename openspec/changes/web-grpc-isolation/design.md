## Context

`protoc-gen-dart-unified` 从单个 `.proto` 生成统一客户端 SDK，支持 HTTP（REST/JSON）与 gRPC 两种传输。运行时层（`transport_factory.dart`）已通过条件导入（`if (dart.library.io) native` / `if (dart.library.js_interop) web`）正确隔离 gRPC：Web 恒走 `transport_web.dart`（仅 HTTP），native 走 `transport_native.dart`（`HttpTransport` + `GrpcTransport`）。

但有两处泄漏导致 Web 构建失败：

1. **Service 生成层**（`service_generator.dart`）：纯 gRPC service（无 `google.api.http` 注解）生成 `*_service.dart` 时无条件 `import '../{proto}.pbgrpc.dart'`（静态、非条件）。该 import 引入 `grpc`/`dart:io`，Web 编译即失败。当前唯一 fixture `user.proto` 全带 http 注解 → 测试从未覆盖 gRPC-only 场景，泄漏长期未被发现。
2. **生成 runtime 模板层**（`runtime_inline_generator.dart`）：单文件 `unified_runtime.dart` 模板内**包含 `GrpcTransport` 实现类**（第 617-662 行），直接引用 `GrpcClient`。Dart 条件导入只能在文件级工作，无法在同一文件内用 `#if` 隔离代码块 → Web 编译必然引入 gRPC 实现代码。

现状还包含技术债：生成的 `Unified<Service>` 持有 `_grpcClient` 字段但零引用，`createTransport` 恒返 `HttpTransport`，`_grpcClient` 字段是死代码。

## Goals / Non-Goals

**Goals:**
- Web 编译产物不含 `grpc`/`dart:io` 依赖（编译期隔离）
- 生成的 `*_service.dart` 对任意 service 不再 `import '*.pbgrpc.dart'`
- `Unified<Service>` 经 `_transport` 统一发起调用（移除 `_grpcClient` 字段）
- 让 `GrpcTransport` 真正可用：完整接入拦截器链、headers/timeout/cancel 透传、错误映射
- 不破坏 HTTP/REST 路径与既有测试

**Non-Goals:**
- 不实现 HTTP fallback / gRPC-Web / ConnectRPC 转码（Web 纯 gRPC 服务明确报错 + 文档声明）
- 不改为多文件输出结构（坚持单文件 `unified_runtime.dart`，即方案 A）
- 不引入运行时 `kIsWeb` 判断（保持编译期条件导入，利于 tree-shaking）
- 不改动 HTTP 传输逻辑、SSE 解析器、interceptor 实现类

## Decisions

### Decision 1: 单文件 runtime 模板删除 GrpcTransport 实现（方案 A）

**选择**：`unified_runtime.dart` 单文件模板只保留 `GrpcClient` 抽象接口与 `createTransport` 工厂函数签名；`GrpcTransport` 实现保留在 `transport_native.dart`（已由条件导入隔离，仅 native 编译）。

**备选**：
- 方案 B（放弃单文件，web 不引入任何 gRPC 生成文件）：最彻底但偏离「单文件」原则，需改动插件多文件输出结构，影响面大，否决。

**理由**：复用成熟的条件导入机制，对用户感知不变（仍只 import `unified_runtime.dart`），最小改动达成隔离。

### Decision 2: Web 纯 gRPC 服务明确报错

**选择**：Web 平台检测到 `grpcClient != null`（即用户试图在 Web 使用纯 gRPC 服务）时，在 `ApiSdk` 构造或 `createTransport` 入口抛出 `UnsupportedError`，附带清晰说明「Web 不支持纯 gRPC 服务，请添加 google.api.http 注解启用 HTTP/REST 或使用 native 平台」。同步更新 `docs/usage.md`。

**备选**：降级为 HTTP fallback（需服务端 gRPC-Web/transcoding 支持，超出插件职责），否决。

**理由**：明确失败优于静默打包失败，避免用户困惑。

### Decision 3: GrpcClient 适配器在 ApiSdk 构造时代理生成

**选择**：`protoc-gen-dart` 生成的 `*ServiceClient` 到 `GrpcClient` 的适配逻辑由 `ApiSdk` 生成代码在构造时内联完成（无反射），适配器实现位于 `transport_native.dart`（native-only）。`ApiSdk` 构造接收用户提供的 `*ServiceClient`，转为 `GrpcClient` 后传给 `createTransport`。

**理由**：`protoc-gen-dart` 生成的 `*ServiceClient` 标准签名（`unaryCall`/`serverStream`）稳定，适配器仅依赖标准签名，最小化耦合；生成时代理避免运行时反射开销。

### Decision 4: GrpcTransport 完整接入拦截器链与 options 透传

**选择**：`transport_native.dart:GrpcTransport` 的 `unaryCall`/`serverStream` 经 `Transport.executeWithInterceptors` 套拦截器链（已实现），并在 `_rawGrpcUnaryCall` 中将 `RpcCallOptions` 映射为 gRPC `CallOptions`：`headers` → metadata，`timeout` → `CallOption.timeout`，`cancelToken` → 桥接到 `ResponseFuture.cancel()`；`GrpcError` → `ApiException`（按 gRPC canonical code）。

**理由**：当前 `_rawGrpcUnaryCall` 直接调用 `_client.unaryCall` 且完全忽略 `options`，导致 auth/tracing headers、timeout、取消均不生效，是 P0 缺陷，必须补全。

## Risks / Trade-offs

- **[Risk] 单文件模板与条件导入天然冲突** → 采用 Decision 1：gRPC 实现外置于 native-only 模块，runtime 只留接口与工厂。
- **[Risk] 现有 HTTP golden 漂移** → `UPDATE_GOLDENS=1` 同步，CI 门禁保护；golden 测试新增 gRPC-only 场景断言。
- **[Risk] 适配器需感知 `protoc-gen-dart` 生成的 `*ServiceClient` API 变更** → 适配器仅用 `unaryCall`/`serverStream` 标准签名，最小化耦合。
- **[Risk] 破坏性变更影响存量生成代码** → 一次性重新生成；迁移指南写入 `docs/usage.md`。
- **[Risk] Web gRPC 取消桥接实现复杂** → 采用 `ResponseFuture.cancel()` 标准 API，native-only 编译不污染 web。

## Migration Plan

1. 修改生成器与 runtime（S1-S9）
2. 新增 gRPC-only fixture + golden + 单测（S10-S13）
3. `UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart` 同步 golden
4. `dart test` + `dart analyze --fatal-infos` 全绿
5. 更新 `docs/usage.md`：声明 Web 不支持纯 gRPC 服务 + 重新生成迁移说明
6. 存量用户重新运行插件生成代码（一次性）

## Open Questions

- Web 平台 `dart:io` 泄漏的精确 CI 检测手段：采用 `dart analyze` + 条件导入静态检查，还是增加 web 编译 smoke test（`dart compile js`）？建议在 S12 同时覆盖两者。
