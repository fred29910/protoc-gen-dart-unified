# Comet Design Handoff

- Change: web-grpc-isolation
- Phase: design
- Mode: compact
- Context hash: 6d72df391a3b5b8eb590eaa13fdcb653956cf0029cdfed3ec5efe32d79af6a98

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/web-grpc-isolation/proposal.md

- Source: openspec/changes/web-grpc-isolation/proposal.md
- Lines: 1-30
- SHA256: efdc8c0a644a14dd345eceb2bcb02197c8cca0263a465df348006db50650b29b

```md
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
```

## openspec/changes/web-grpc-isolation/design.md

- Source: openspec/changes/web-grpc-isolation/design.md
- Lines: 1-77
- SHA256: 6b6449107b16921173101918c246b6d709c66b240c511de2b1f921af67b340b7

```md
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
```

## openspec/changes/web-grpc-isolation/tasks.md

- Source: openspec/changes/web-grpc-isolation/tasks.md
- Lines: 1-31
- SHA256: c67abcad8791e94f4c8b0a138775bca982eba78741f39d5aeb66343198ba320f

```md
## 1. Generator changes (remove pbgrpc dependency)

- [ ] 1.1 `service_generator.dart:_buildDirectives()` — remove `!_useHttp` branch that imports `../{proto}.pbgrpc.dart`; service file keeps only `unified_runtime.dart` + `*.pb.dart`
- [ ] 1.2 `service_generator.dart:_buildUnifiedImpl()` — remove `_grpcClient` field and `grpcClient` ctor param for gRPC services; `Unified<Service>` holds only `_transport` + `_interceptors`
- [ ] 1.3 `service_generator.dart:_buildGrpcUnaryCall()` — change to `_transport.unaryCall<Output>(...)` with `options: ctx.options`
- [ ] 1.4 `service_generator.dart:_buildGrpcServerStreamBody()` — change to `_transport.serverStream<Output>(...)` with `options: ctx.options`
- [ ] 1.5 `service_generator.dart:_buildApiSdk()` — accept user-provided `*ServiceClient`, build `GrpcClient` adapter (native-only), pass to `createTransport`; HTTP services pass `grpcClient: null`

## 2. Runtime changes (make gRPC truly usable + conditional isolation)

- [ ] 2.1 `runtime_inline_generator.dart` — delete `GrpcTransport` class from template; retain abstract `GrpcClient` + `createTransport` factory signature (no `grpc`/`dart:io` import)
- [ ] 2.2 `transport_native.dart:GrpcTransport.unaryCall` — ensure `executeWithInterceptors` wraps the chain (already present); `_rawGrpcUnaryCall` maps `RpcCallOptions.headers` → gRPC metadata, `timeout` → `CallOption.timeout`
- [ ] 2.3 `transport_native.dart:GrpcTransport.serverStream` — bridge `RpcCancelToken` to `ResponseFuture.cancel()`; map `RpcCallOptions.headers`/`timeout` to gRPC `CallOptions`
- [ ] 2.4 `transport_native.dart` — add `*ServiceClient → GrpcClient` adapter (native-only): `unaryCall`/`serverStream` delegate to `*ServiceClient` with `CallOptions` from `RpcCallOptions`
- [ ] 2.5 `transport_native.dart` — map `GrpcError` → `ApiException` by gRPC canonical code in `_rawGrpcUnaryCall` / `_rawGrpcServerStream`
- [ ] 2.6 `transport_factory.dart:createTransport` — confirm web path returns `HttpTransport` always; native returns `GrpcTransport` when `grpcClient != null`
- [ ] 2.7 `transport_web.dart` — confirm no `GrpcTransport` reference; add clear `UnsupportedError` when `grpcClient != null` on web

## 3. Testing & verification

- [ ] 3.1 Add gRPC-only fixture `test/fixtures/echo.proto` (no `google.api.http`)
- [ ] 3.2 Integration test: generate `echo_service.dart`, assert no `import '*.pbgrpc.dart'`, `UnifiedEcho` has no `_grpcClient` field, method body calls `_transport.unaryCall`
- [ ] 3.3 `transport_native_test.dart`: verify `GrpcTransport` delegation + error mapping with `TestGrpcClient` double
- [ ] 3.4 Web isolation check: `dart analyze` + conditional-import static check (or `dart compile js` smoke test) confirms no `grpc`/`dart:io` in web compile graph
- [ ] 3.5 `UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart` — sync golden; extend golden to cover gRPC-only scenario
- [ ] 3.6 `dart test` + `dart analyze --fatal-infos` all green

## 4. Docs & migration

- [ ] 4.1 `docs/usage.md` — declare Web does not support pure gRPC services; add regeneration migration note (breaking change)
- [ ] 4.2 Mark `docs/plan/2026-07-15-web-grpc-isolation.md` status as implemented (post-merge)
```

## openspec/changes/web-grpc-isolation/specs/grpc-code-generation/spec.md

- Source: openspec/changes/web-grpc-isolation/specs/grpc-code-generation/spec.md
- Lines: 1-42
- SHA256: c8c7a77fb0a6c5767b99b3dbc14e5c25e65f9985a8f907f4b012ecd3ffde65f9

```md
# grpc-code-generation Specification (delta)

## Purpose
Update gRPC transport delegation: `Unified<Service>` invokes calls through `_transport` uniformly (no direct `_grpcClient`/`*ServiceClient` reference), and `GrpcTransport` lives in the native-only module with full interceptor-chain and options passthrough.

## Requirements

### Requirement: gRPC transport delegation

The system SHALL generate `Unified<Service>` that delegates gRPC calls to the transport returned by `createTransport`, not to a directly-held `*ServiceClient`.

#### Scenario: Unary gRPC call via transport
- **WHEN** a method is configured for gRPC transport
- **THEN** the generated code calls `_transport.unaryCall<Output>(...)` (no `_grpcClient!.unaryCall`)

#### Scenario: gRPC metadata passthrough
- **WHEN** `RpcCallOptions.headers` is set
- **THEN** `GrpcTransport` passes headers as gRPC `CallOptions` metadata

#### Scenario: gRPC timeout passthrough
- **WHEN** `RpcCallOptions.timeout` is set
- **THEN** `GrpcTransport` applies the timeout to the gRPC call

#### Scenario: gRPC cancellation passthrough
- **WHEN** `RpcCancelToken.cancel()` is invoked
- **THEN** `GrpcTransport` cancels the underlying gRPC `ResponseFuture`

### Requirement: gRPC error mapping

The system SHALL map `GrpcError` to `ApiException` subclasses using the gRPC canonical code directly.

#### Scenario: gRPC error code mapped
- **WHEN** a gRPC call fails with `GrpcError.notFound`
- **THEN** the generated code throws `NotFoundException`

### Requirement: Server streaming gRPC

The system SHALL support server streaming via gRPC native `ResponseStream<T>` through `_transport.serverStream`.

#### Scenario: Server streaming gRPC call
- **WHEN** a method has `returns (stream OutputType)` and gRPC transport is active
- **THEN** the generated code returns `Stream<OutputType>` from `_transport.serverStream`
```

## openspec/changes/web-grpc-isolation/specs/transport-selection/spec.md

- Source: openspec/changes/web-grpc-isolation/specs/transport-selection/spec.md
- Lines: 1-22
- SHA256: f6910b51e8c1c11039e92cc7231efe85419d7d680d0a5471d49241c125f68b94

```md
# transport-selection Specification (delta)

## Purpose
Extend the conditional-import split requirement: the generated `unified_runtime.dart` single file must contain no gRPC implementation code; gRPC implementation lives only in the native conditional-import compilation unit.

## Requirements

### Requirement: Conditional import split

The system SHALL use conditional imports to keep Web builds free of gRPC dependencies.

#### Scenario: Web build excludes native transport
- **WHEN** the package is compiled for Web
- **THEN** the generated import graph does not reference the native transport file

#### Scenario: Generated runtime template contains no gRPC code
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output does not define `GrpcTransport` and does not import `grpc` or `dart:io`

#### Scenario: GrpcTransport implementation isolated to native unit
- **WHEN** gRPC transport is used on Native
- **THEN** `GrpcTransport` is provided by `transport_native.dart` (conditional-import only, not compiled for Web)
```

## openspec/changes/web-grpc-isolation/specs/web-grpc-build-isolation/spec.md

- Source: openspec/changes/web-grpc-isolation/specs/web-grpc-build-isolation/spec.md
- Lines: 1-42
- SHA256: 26b064281b5450c2af3346099457555374cfbb15b203d3b2e0d74ef6138d281c

```md
# web-grpc-build-isolation Specification

## Purpose
确保 Web 编译产物不含 `grpc`/`dart:io` 依赖的编译期隔离机制：生成的 service 文件去 pbgrpc import，生成的单文件 runtime 模板去 GrpcTransport 实现。

## Requirements

### Requirement: Service file excludes pbgrpc import

The system SHALL NOT generate a static `import '*.pbgrpc.dart'` in any generated `*_service.dart` file, regardless of whether the service uses gRPC or HTTP transport.

#### Scenario: gRPC-only service generates no pbgrpc import
- **WHEN** a service has no `google.api.http` annotation (pure gRPC)
- **THEN** the generated `*_service.dart` contains no `import '*.pbgrpc.dart'` directive

#### Scenario: Unified impl uses transport uniformly
- **WHEN** the `Unified<Service>` implementation makes a call
- **THEN** it invokes `_transport.unaryCall` / `_transport.serverStream` (no direct `_grpcClient` reference)

### Requirement: Generated runtime template excludes gRPC implementation

The system SHALL emit a `unified_runtime.dart` single-file template that contains no gRPC implementation code (no `GrpcTransport` class, no `grpc`/`dart:io` import).

#### Scenario: Runtime template has no gRPC class
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output does not define `class GrpcTransport` and does not import `grpc` or `dart:io`

#### Scenario: Runtime template retains GrpcClient interface
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output retains the abstract `GrpcClient` interface and the `createTransport` factory signature

### Requirement: Web build excludes gRPC dependencies

The system SHALL ensure Web compilation does not pull in `grpc` or `dart:io` dependencies through generated output.

#### Scenario: Web compile graph excludes native transport
- **WHEN** the generated package is compiled for Web
- **THEN** the import graph does not reference `transport_native.dart` or `grpc`/`dart:io`

#### Scenario: Web pure-gRPC service fails clearly
- **WHEN** a pure gRPC service is instantiated on Web with a `grpcClient` provided
- **THEN** the system throws `UnsupportedError` stating Web does not support pure gRPC services
```

