# 规划：Web 端隔离 gRPC 代码（环境差异化打包）

**日期**：2026-07-15
**状态**：规划（待评审后实施）
**关联问题**：前次功能完整度评审 P0（gRPC 传输非功能化）+ Web gRPC 依赖泄漏
**关联文档**：`docs/reviews/2026-07-15-functional-completeness-review.md`

---

## 1. 背景与目标

### 1.1 目标

让不同目标环境（Web / Native）在编译期打包**不同底层文件**，确保 **Web 端不引入 `grpc` / `dart:io` 依赖**，避免 Web 构建失败。

### 1.2 当前机制（已实测）

| 层 | 机制 | Web 是否隔离 gRPC |
|----|------|------------------|
| 运行时传输 `transport_factory.dart` | 条件导入：`if (dart.library.io) native` / `if (dart.library.js_interop) web` | ✅ 是 |
| 生成 runtime `unified_runtime.dart` | 仅 HTTP、无 `dart:io` import | ✅ 是 |
| 生成 service 文件 `*_service.dart` | **静态** `import '../x.pbgrpc.dart'`（当 service 无 http 注解时） | ❌ 否 |

### 1.3 问题陈述

- 纯 gRPC 服务（无任何 `google.api.http` 注解）生成的 `*_service.dart` 会**无条件** `import '../{proto}.pbgrpc.dart'`（`service_generator.dart:_buildDirectives`，`!_useHttp` 分支）。
- 该 import 非条件导入、不区分平台 → Web 编译时引入 `grpc`/`dart:io`，**构建失败**。
- 当前唯一 fixture `user.proto` 全带 http 注解 → `_useHttp=true` → 从不生成 pbgrpc import，测试**从未覆盖** gRPC-only 场景，泄漏长期未被发现。
- 该 `*.pbgrpc.dart` import 当前是**冗余依赖**：生成的 gRPC 方法体实际调用 `_transport.unaryCall`（HTTP），`_grpcClient` 字段零引用（`createTransport` 恒返 `HttpTransport`）。

**结论**：Web 隔离 gRPC 只做了一半（运行时层），service 文件层仍有泄漏。

---

## 2. 设计原则

1. **编译期隔离优先**：沿用既有的条件导入（conditional import）模式，不做运行时 `kIsWeb` 判断（与 `lib/src/runtime/AGENTS.md` 约定一致，利于 tree-shaking）。
2. **单点收口**：把 gRPC 委托能力收敛进已条件化的 runtime，service 文件只依赖 `unified_runtime.dart`，不再直接引用 `*.pbgrpc.dart`。
3. **消除死代码**：借机修复 P0 —— 让 `GrpcTransport` 真正可用，而非生成永不使用的 `_grpcClient` 字段。
4. **不破坏现有 HTTP 路径**：HTTP/REST 生成与测试保持不变。

---

## 3. 目标架构

```
生成产物（每个 service）:
  user_service.dart          ← 只 import unified_runtime.dart + user.pb.dart
  user_service_mock.dart
  user_service_example_test.dart
  unified_runtime.dart       ← 条件导入已在此层隔离 gRPC

unified_runtime.dart 内部（已条件化）:
  createTransport(endpoint, {grpcClient}):
    native (dart.library.io)   → grpcClient != null ? GrpcTransport(grpcClient) : HttpTransport
    web    (dart.library.js_interop) → HttpTransport   // gRPC 代码根本不编译进 web
```

- `GrpcTransport` 仅存在于 `transport_native.dart`（native 编译单元），内部把 `*ServiceClient` 适配为 `GrpcClient`；
- Web 构建因条件导入**不会编译** `transport_native.dart`，自然不碰 `grpc`/`dart:io`；
- service 文件不再 `import *.pbgrpc.dart`，gRPC 依赖被完全隔离在 native-only 模块中。

---

## 4. 实施步骤

### 4.1 生成器改动（去 pbgrpc 依赖）

- [ ] **S1** `service_generator.dart:_buildDirectives()`：移除 `!_useHttp` 时 `import '../{proto}.pbgrpc.dart'` 的分支。service 文件只保留 `unified_runtime.dart` + `*.pb.dart` 两个 import。
- [ ] **S2** `service_generator.dart`：gRPC 服务的 `Unified<Service>` 构造参数调整 —— 不再生成 `_grpcClient` 字段与 `grpcClient` 命名参数（交由 `createTransport`/runtime 内部处理），或保留但明确仅 native 使用（见 S4 决策）。
- [ ] **S3** `service_generator.dart:_buildGrpcUnaryCall` / `_buildGrpcServerStreamBody`：改为通过 `_transport`（即 `createTransport` 返回的 `GrpcTransport` 或 `HttpTransport`）发起调用，移除对 `_grpcClient` 的引用；调用时携带 `RpcCallOptions`（headers/timeout/cancelToken）以接入拦截器链。

### 4.2 运行时改动（让 gRPC 真正可用 + 条件隔离）

- [ ] **S4** `transport_native.dart`：新增 `GrpcTransport implements Transport`，构造接收 `GrpcClient`，`unaryCall`/`serverStream` 委托到 `GrpcClient`，并用 `executeWithInterceptors` 套拦截器链；实现 gRPC 错误→`ApiException` 映射、gRPC metadata 透传（`RpcCallOptions.headers`）、gRPC 取消桥接（`RpcCancelToken`→`ResponseFuture.cancel`）。
- [ ] **S5** `transport_factory.dart:createTransport`：当 `grpcClient != null` 且为 native 时返回 `GrpcTransport`，否则 `HttpTransport`（Web 恒 `HttpTransport`）。`grpcClient` 参数类型由 `dynamic` 收敛为 `GrpcClient?`。
- [ ] **S6** 生成 `unified_runtime.dart` 模板同步上述内容（保持 `lib/src/runtime/` 与 `runtime_inline_generator.dart` 一致）；确认生成模板**不含** `dart:io` import（gRPC 相关代码仅出现在 native 条件分支中，单文件模板需改为通过条件导入拆分，或保留 `GrpcTransport` 抽象但 native 实现外置 —— 见 §5 决策）。
- [ ] **S7** 提供 `*ServiceClient → GrpcClient` 适配器工厂（位于 `transport_native.dart` 或新的 `grpc_adapter.dart`，仅 native 编译）：接收 `UserServiceClient` 等，暴露 `unaryCall<T>`/`serverStream<T>`。

### 4.3 生成入口与参数

- [ ] **S8** `ApiSdk` 构造：将用户提供的 `*ServiceClient` 经适配器转为 `GrpcClient`，传给 `createTransport`；HTTP 服务的 `grpcClient` 保持 `null`。
- [ ] **S9** 确立"平台信息不传入生成器"前提下的行为契约：纯 gRPC 服务在 Web 构建会因 `grpcClient==null` 触发明确错误（或文档声明 Web 不支持纯 gRPC 服务），而非静默打包失败。

### 4.4 测试与验证

- [ ] **S10** 新增 gRPC-only fixture（如 `test/fixtures/echo.proto`，无 `google.api.http`），生成 `*_service.dart` 并断言**不含** `import '...pbgrpc.dart'`、`Unified<Service>` 经由 `createTransport` 获取传输层。
- [ ] **S11** 新增 `transport_native_test.dart`：验证 `GrpcTransport` 委托与错误映射（用 `TestGrpcClient` 双）。
- [ ] **S12** 在纯 Dart（native）环境编译生成产物，验证 gRPC 路径可运行；在 web 解析/编译路径验证无 `grpc`/`dart:io` 引入（可用 `dart analyze` + 条件导入静态检查，或 web 编译 smoke test）。
- [ ] **S13** 更新 golden 文件（`UPDATE_GOLDENS=1`），扩展 golden 测试覆盖 gRPC-only 场景。
- [ ] **S14** 运行 `dart test` + `dart analyze --fatal-infos` 全绿。

---

## 5. 关键决策点（需确认）

1. **单文件 vs 条件导入拆分**：`unified_runtime.dart` 当前是单文件模板。若要把 `GrpcTransport` 真正实现（含 `grpc`/`dart:io`）且不让 Web 编译它，单文件模板无法满足（Dart 不支持文件内条件代码块）。选项：
   - **A（推荐）**：gRPC 委托留在 `lib/src/runtime/transport_native.dart`（已由条件导入隔离），生成的 `unified_runtime.dart` **只声明 `GrpcClient` 接口与 `createTransport` 工厂签名**，具体 `GrpcTransport` 实现由 native 条件导入提供。service 文件仍只依赖 `unified_runtime.dart`，但 runtime 文件集合在 native 下额外含 `transport_native.dart`。
   - **B**：放弃单文件约束，让 Web 构建直接不引入任何 gRPC 相关生成文件（最彻底，但偏离"单文件"原则）。
2. **Web 对纯 gRPC 服务的处理**：报错（明确不支持）还是降级为 HTTP fallback（需服务端支持 gRPC-Web/transcoding，超出范围）。建议**明确报错 + 文档声明**。

---

## 6. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 单文件 `unified_runtime.dart` 与条件导入天然冲突 | 采用决策 A：gRPC 实现外置于 native-only 模块，runtime 只留接口与工厂 |
| 现有 HTTP golden 漂移 | `UPDATE_GOLDENS=1` 同步，CI 门禁保护 |
| 适配器需感知 `protoc-gen-dart` 生成的 `*ServiceClient` API 变更 | 适配器仅用 `unaryCall`/`serverStream` 标准签名，最小化耦合 |
| 破坏存量生成代码（破坏性变更） | 一次性重新生成；迁移指南写入 `docs/usage.md` |

---

## 7. 验收标准

- [ ] Web 构建（解析+编译路径）**不包含** `grpc`、`dart:io` 依赖。
- [ ] 纯 gRPC 服务在 Native 下经 `GrpcTransport` 真正发起 gRPC 调用（端到端可用）。
- [ ] 生成的 `*_service.dart` 对任意 service **不再** `import '*.pbgrpc.dart'`。
- [ ] 现有 HTTP/REST 路径与全部既有测试不受影响（全绿）。
- [ ] gRPC-only 场景进入 fixture + golden + 单测覆盖。
