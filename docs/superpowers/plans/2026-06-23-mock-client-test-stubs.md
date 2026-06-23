---
change: mock-client-test-stubs
design-doc: docs/superpowers/specs/2026-06-23-mock-client-test-stubs-design.md
base-ref: 209cd924daa41e0a19118b38764f6a69df94623d
---

# Mock 客户端与单测桩生成 — 实施计划

## 概述

基于 `docs/superpowers/specs/2026-06-23-mock-client-test-stubs-design.md` 技术设计，实施 Mock 客户端和示例测试生成能力。

## 任务清单

### 1. Mock 客户端生成器实现

**文件**：`lib/src/generators/mock_service_generator.dart`（新增）

- 创建 `MockServiceGenerator` 类，接收 `ServiceModel`
- 使用 `code_builder` 构造 AST
- 生成 `@GenerateNiceMocks([MockXxxService])` 注解类
- 支持 Unary 方法（`Future<T>`）和 Server Streaming 方法（`Stream<T>`）
- 方法体统一为 `throw UnimplementedError()`
- 正确 import：`package:mockito/annotations.dart`、`../{proto}.pb.dart`、`{service}_service.dart`
- `DartFormatter` 格式化输出

### 2. 示例测试生成器实现

**文件**：`lib/src/generators/example_test_generator.dart`（新增）

- 创建 `ExampleTestGenerator` 类，接收 `ServiceModel`
- 使用 `code_builder` 构造 AST
- 生成 `main()` + `group('XxxService', ...)` 结构
- 每个方法生成一个 `test()` 块
- Unary stub 注释：`// when(mock.method(any)).thenAnswer((_) async => T())`
- Server Streaming stub 注释：`// when(mock.method(any)).thenAnswer((_) => Stream.value(T()))`
- 正确 import：`package:test/test.dart`、`package:mockito/mockito.dart`、`../{proto}.pb.dart`、`{service}_service_mock.dart`、`{service}_service.dart`
- `DartFormatter` 格式化输出

### 3. 主生成器集成

**文件**：`lib/src/generator.dart`（修改）

- 修改 `CodeGenerator.generate()`，在生成 service 文件后额外调用 `MockServiceGenerator` 和 `ExampleTestGenerator`
- 新增 `_mockEnabled` 字段，从 `CodeGeneratorRequest.parameter` 解析 `mock` 参数（默认 `true`）
- 当 `mock=false` 时跳过 mock 和测试文件生成
- 输出文件名：`{snake_case_service_name}_mock.dart`、`{snake_case_service_name}_example_test.dart`

### 4. Golden 测试

**文件**：`test/goldens/user_service_mock.dart.golden`（新增）、`test/goldens/user_service_example_test.dart.golden`（新增）、`test/golden/golden_test.dart`（修改）

- 新增 `user_service_mock.dart.golden`：mock 文件期望输出
- 新增 `user_service_example_test.dart.golden`：example_test 文件期望输出
- 修改 `golden_test.dart`，新增两个 golden 测试用例
- 运行 `UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart` 生成 golden 文件

### 5. 验证与收尾

- 运行 `dart test` 确保所有测试通过
- 运行 `dart analyze` 确保零错误
- 验证生成的 mock 文件可被 `dart analyze` 分析通过
