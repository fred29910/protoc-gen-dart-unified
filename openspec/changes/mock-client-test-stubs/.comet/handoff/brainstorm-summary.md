# Brainstorm Summary

- Change: mock-client-test-stubs
- Date: 2026-06-23

## 确认的技术方案

**方案 A：独立 Generator + 独立文件**（已确认）

- `MockServiceGenerator`：独立类，接收 `ServiceModel`，用 `code_builder` 生成 `*_mock.dart`，包含 `@GenerateNiceMocks([MockXxxService])` 注解
- `ExampleTestGenerator`：独立类，接收 `ServiceModel`，生成 `*_example_test.dart`，包含 `group/test/when/thenAnswer` stub 模板
- `CodeGenerator.generate()` 依次调用三个 Generator，输出三个独立文件
- `mock` 插件参数（默认 `true`），`mock=false` 时跳过 mock 和测试文件生成

## 关键取舍与风险

- **mockito 版本兼容性**：生成的注解代码保持最小化，仅使用 `@GenerateNiceMocks`
- **Server Streaming mock**：Mock 方法返回 `Stream<T>`，示例测试用 `Stream.value()` 提供 stub
- **golden 文件维护**：新增两个 golden 文件，随生成器变更同步更新

## 测试策略

- golden 测试覆盖 mock 文件和 example_test 文件生成
- 生成的文件通过 `dart analyze` 零错误验证
- 完整测试套件 `dart test` 全部通过

## Spec Patch

（无 — 现有 spec 已覆盖需求）
