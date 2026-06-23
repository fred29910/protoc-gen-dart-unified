## Why

当前 `protoc-gen-dart-unified` 生成的服务代码（P1-P3）缺少配套的 Mock 测试基础设施，开发者需要手写 Mock 类来单元测试，成本高且不一致。本变更在 Phase 4 中为每个服务自动生成基于 mockito 的 Mock 客户端和示例测试模板，实现开箱即用的测试体验。

## What Changes

- 新增 `MockServiceGenerator`：为每个服务生成 `*_mock.dart` 文件，包含 `@GenerateNiceMocks` 注解的 Mock 类
- 新增 `ExampleTestGenerator`：为每个服务生成 `*_example_test.dart` 文件，包含基础测试用例模板
- 修改 `CodeGenerator`（`lib/src/generator.dart`）：在生成 `*_service.dart` 的同时输出 `*_mock.dart` 和 `*_example_test.dart`
- 新增 golden 测试覆盖 Mock 和示例测试文件的生成
- 新增 `mock` 插件参数（默认 `true`），控制是否生成 Mock 和测试文件

## Capabilities

### New Capabilities

- `mock-client-generation`：基于 mockito `@GenerateNiceMocks` 自动生成 Mock 客户端类，支持 Unary/Server Streaming 方法
- `example-test-stub-generation`：生成示例测试文件，包含 test 依赖导入、group 结构、基础 stub 模板

### Modified Capabilities

（无 — 不修改已有 spec 的需求，仅新增能力）

## Impact

- **新增文件**：`lib/src/generators/mock_service_generator.dart`、`lib/src/generators/example_test_generator.dart`
- **修改文件**：`lib/src/generator.dart`（输出额外文件）、`test/golden/golden_test.dart`（新增 golden 测试）
- **新增 golden 文件**：`test/goldens/user_service_mock.dart.golden`、`test/goldens/user_service_example_test.dart.golden`
- **新增 spec 目录**：`openspec/changes/mock-client-test-stubs/specs/mock-client-generation/spec.md`、`openspec/changes/mock-client-test-stubs/specs/example-test-stub-generation/spec.md`
- **依赖**：不新增运行时依赖；生成的 mock 文件依赖 `mockito`（由用户项目自行添加）
