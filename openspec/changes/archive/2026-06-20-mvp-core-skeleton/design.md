## Context

`protoc-gen-dart-unified` 当前只有 `docs/design.md` 设计文档，尚无 Dart package、生成器入口、runtime contract、测试 fixture 或 golden 测试基础设施。该 change 按用户确认保持为一个完整 change，但实现优先级聚焦 design.md 的 **Phase 1 MVP 核心骨架**：先让插件可运行、能读取 `google.api.http`、能生成可分析/可测试的 unary service 基础产物，并为后续 Phase 2/3/4 建立可扩展结构。

当前环境 Dart SDK 为 `3.12.2`；pub.dev 最新依赖要求 SDK 上限覆盖 `^3.10.0`，因此项目 SDK 约束采用 `>=3.10.0 <4.0.0`。

## Goals / Non-Goals

**Goals:**

- 建立可运行的 Dart protoc 插件工程，入口从 stdin 读取 `CodeGeneratorRequest` 并向 stdout 写出 `CodeGeneratorResponse`。
- 使用官方 `protoc_plugin` / `protobuf` descriptor 基建遍历 proto service/method，避免手写 wire 解析。
- 打通 `google.api.http` custom option 读取，覆盖 `ExtensionRegistry` 注册、`MethodOptions` 重解析、`Annotations.http` 提取。
- 建立 `HttpRuleModel`、`ServiceModel`、`MethodModel` 等内部模型，承载 unary path/query/body/additional_bindings 的基础映射语义。
- 建立 runtime contract：`Protocol`、`ClientOptions`、`Transport`、`RpcInterceptor`、`ApiException`、HTTP/gRPC transport 接口与 conditional import transport factory。
- 建立 golden 测试脚手架与 custom option 专项测试，确保后续扩展不会破坏生成器基础。
- 确保生成产物可通过 `DartFormatter` 格式化，并通过 `dart analyze`。

**Non-Goals:**

- 不在 Phase 1 实现完整 Client Streaming / Bidi Streaming；仅保留 descriptor 数据模型与后续扩展点。
- 不手写 gRPC `ClientChannel`、marshalling 或流式实现；gRPC transport 只委托 `*.pbgrpc.dart` 生成的 client。
- 不实现完整 OpenTelemetry SDK；仅保留 traceparent 注入扩展点。
- 不实现完整 grpc-gateway 全量 golden 对照；Phase 1 建立测试结构与核心 unary 覆盖，后续补齐复杂 HttpRule 行为。
- 不创建 Flutter 示例应用或发布到 pub.dev；仅建立 package 与本地验证。

## Decisions

### Decision 1: 使用最新兼容 Dart 依赖，SDK 约束为 `>=3.10.0 <4.0.0`

- `protoc_plugin: 25.0.0` 要求 `sdk ^3.7.0` 并依赖 `protobuf ^6.0.0`、`dart_style ^3.0.0`。
- `dart_style: 3.1.9` 与 `test: 1.31.1` 要求 `sdk ^3.10.0`。
- `grpc: 5.1.0` 与 `lints: 6.1.0` 要求 `sdk ^3.8.0`。
- 当前环境 Dart SDK 为 `3.12.2`，因此采用 `>=3.10.0 <4.0.0` 能覆盖最新依赖并保留 Dart 3 兼容性。

### Decision 2: 插件本体使用 Dart + `protoc_plugin` descriptor API

插件从 stdin/stdout 与 protoc 交互，复用 `CodeGeneratorRequest` / `CodeGeneratorResponse` 和 `FileDescriptorProto`。不手写 protobuf wire 解析，降低维护成本并符合 design.md 的“插件本体用 Dart 编写”原则。

### Decision 3: `google.api.http` 通过 `ExtensionRegistry` 重解析读取

`google.api.http` 是 custom option，不能只依赖 descriptor 默认字段。实现路径：

1. 使用 `google/api/http.pb.dart` / `annotations.pb.dart` 生成或引入的 `Annotations.http` 扩展。
2. 构造 `ExtensionRegistry` 并注册该扩展。
3. 对 `MethodOptions` bytes 使用 `mergeFromBuffer(..., registry)` 重解析。
4. 通过 `getExtension(Annotations.http)` 提取 `HttpRule`。

该路径必须在 custom option 专项测试中覆盖，否则注解会以 unknown fields 形式静默丢失。

### Decision 4: 内部模型先承载完整 HttpRule 语义，但 Phase 1 只实现 unary 常见映射

`HttpRuleModel` 必须包含 `kind`、`path`、`body`、`responseBody`、`additionalBindings` 等字段，避免后续扩展时推倒重来。Phase 1 的生成器优先实现：

- `GET / POST / PUT / PATCH / DELETE` 基础方法映射。
- 简单 path 参数绑定 `{id}`。
- 未绑定且非 body 字段的 query 展平。
- `body: "*"` 与 `body: "field"` 的基础模型表达。
- `response_body` 与 `additional_bindings` 的数据结构保留，可在后续补全生成逻辑。

### Decision 5: Phase 1 在当前 package 内以 `lib/src/runtime/` 作为 runtime contract 占位

用户确认 Phase 1 采用单 package runtime 占位：runtime contract 不直接依赖 Flutter，优先支持纯 Dart/CLI；生成 SDK 文件 import runtime 的 `Protocol`、`ClientOptions`、`Transport`、`ApiException` 等类型。Flutter 项目可作为 consumer 引入同一 runtime。独立 `packages/protoc_gen_dart_unified_runtime` package 作为后续演进方向，不在 Phase 1 创建。

### Decision 6: transport 通过 conditional import 编译期切分

按 design.md 的 Tree-Shaking 方案：

```text
transport_factory.dart
  -> transport_stub.dart
     if (dart.library.io) transport_native.dart
     if (dart.library.js_interop) transport_web.dart
```

- Web 编译时不引用 native transport，避免 `grpc` 包进入 Web 产物。
- Native 编译时可选择 HTTP 或 gRPC；`Protocol.auto` 在 Native 且 transport 包含 grpc 时优先 grpc。
- 当 `transport=http` 时不生成 native 分片，彻底避免 grpc import。

### Decision 7: golden 测试作为生成器主测试策略

使用 `package:test` 管理测试，fixture proto 生成 golden Dart 输出。测试至少覆盖：

- 插件入口可生成 `CodeGeneratorResponse`。
- custom option 读取不丢失 `google.api.http`。
- unary service 生成输出格式稳定。
- `DartFormatter` 对生成源码幂等。

## Risks / Trade-offs

- **[Risk] `google.api.http` custom option 读取失败** → 通过 `ExtensionRegistry` 专项测试和 fixture 覆盖；失败时测试直接暴露 unknown fields 丢失问题。
- **[Risk] 最新依赖之间版本不兼容** → 使用 `dart pub get` 与 `dart analyze` 验证；若 `protoc_plugin 25.0.0` 与 `grpc 5.1.0` 的 `protobuf ^6.0.0` 冲突，通过 lockfile 解析解决。
- **[Risk] 单文件生成与 Tree-Shaking 存在张力** → 采用“核心单文件 + 必要 transport 分片”的折中，不追求完全零分片。
- **[Risk] HTTP transcoding 复杂度高于 Phase 1** → 先建立模型与基础 unary 生成，复杂 grpc-gateway golden 行为后续补齐。
- **[Risk] gRPC 依赖进入 Web 包体** → 通过 conditional import 编译期隔离，并在 Web 编译验证中确认 native transport 未被引用。

## Migration Plan

- 当前仓库无运行时代码，迁移动作等价于初始化 Dart package。
- 部署/使用路径：`dart pub global activate` 或 `dart run protoc_gen_dart_unified`。
- 回滚策略：若生成器输出不稳定，可移除全局激活版本并回退到上一提交；OpenSpec change 未归档前保留设计文档与任务状态。

## Open Questions

- `google/api/http.pb.dart` / `annotations.pb.dart` 是否随仓库 vendored，还是通过 protoc include path 由用户工程提供？
- Phase 1 是否需要立即支持 `response_body` 与 `additional_bindings` 的生成逻辑，还是只建立模型与测试 TODO？
