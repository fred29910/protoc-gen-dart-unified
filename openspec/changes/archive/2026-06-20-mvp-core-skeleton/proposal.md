## Why

当前仓库只有 `docs/design.md`，缺少可运行的 Dart 项目骨架、生成器、runtime、测试与发布基础。`protoc-gen-dart-unified` 需要先把 design.md 中 Phase 1 的核心能力落地：Dart protoc 插件、`google.api.http` 读取、Unary RPC 生成、Web/Native 编译期 transport 切分、统一错误映射与 golden 测试地基。

## What Changes

- 新建 Dart package 结构：`bin/protoc_gen_dart_unified.dart`、`lib/`、`test/`、`analysis_options.yaml`、`pubspec.yaml`。
- 引入最新兼容依赖：`protoc_plugin 25.0.0`、`protobuf 6.0.0`、`dart_style 3.1.9`、`code_builder 4.11.1`、`args 2.7.0`、`dio 5.9.2`、`grpc 5.1.0`、`test 1.31.1`、`lints 6.1.0`，SDK 约束对齐当前环境 `>=3.10.0 <4.0.0`。
- 实现 generator 基础流程：stdin 读取 `CodeGeneratorRequest`，stdout 写出 `CodeGeneratorResponse`，遍历 service/method descriptor。
- 实现 `google.api.http` custom option 读取：通过 `ExtensionRegistry` 注册 `Annotations.http` 并重解析 `MethodOptions`。
- 建立 HTTP mapping 模型：支持 unary 的 path/query/body 基础映射、`response_body`、`additional_bindings` 的数据结构；Phase 1 优先覆盖 unary 常见路径，完整 grpc-gateway golden 行为作为后续迭代验收基准。
- 建立 runtime contract：`Protocol`、`ClientOptions`、`Transport`、`RpcInterceptor`、`ApiException`、HTTP/gRPC transport 接口与 conditional import transport factory。
- 建立 golden 测试脚手架：fixture proto → generated output golden；custom option 专项测试；格式化幂等测试。
- 配置 CI/本地验证：`dart format`、`dart analyze`、`dart test`。

## Capabilities

### New Capabilities

- `dart-generator-scaffold`: Dart protoc 插件工程、入口、descriptor 遍历与 `CodeGeneratorResponse` 输出。
- `google-api-http-parser`: `google.api.http` custom option 读取、`HttpRuleModel` 与 `ExtensionRegistry` 测试。
- `unary-service-generation`: 面向 unary RPC 的 facade/service/generator 基础输出。
- `transport-selection`: `Protocol.auto` 判定、Web/Native conditional import、HTTP/gRPC transport 接口。
- `unified-error-mapping`: `ApiException` 体系与 gRPC code ↔ HTTP status 映射。
- `golden-test-harness`: fixture、golden 文件、custom option 与格式化测试脚手架。
- `runtime-contract`: 生成 SDK 依赖的 runtime API、options、interceptor、exception、transport 抽象。

### Modified Capabilities

<!-- 当前仓库没有现有 OpenSpec specs，因此本 change 不修改既有 capability。 -->

## Impact

- 新增 Dart 项目骨架与依赖，不修改既有 `docs/design.md`。
- 生成器将依赖官方 `protoc_plugin`/`protobuf` 的 descriptor 基建，不手写 wire 解析。
- gRPC 侧仅预留委托 `*.pbgrpc.dart` 的接口与 native transport 分片；Phase 1 不手写 `ClientChannel`。
- HTTP 侧以 `dio` 作为 unary 默认客户端；Web 编译期通过 conditional import 避免引入 `grpc`。
- 测试以 `package:test` + golden files 为核心，后续扩展 grpc-gateway 对照基线。
