## Context

`protoc-gen-dart-unified` 已完成 P1-P3 全部功能（MVP 核心、服务治理与观测、流式传输）。当前 `ServiceGenerator` 为每个 proto 服务生成单文件 `*_service.dart`，包含抽象接口 + Unified 实现 + ApiSdk 入口。

Phase 4 需要补充测试生态：自动生成 Mock 客户端和示例测试模板，让开发者无需手写 mock 即可单元测试。

现有代码结构：
- `lib/src/generator.dart`：主入口，遍历 services 调用 `ServiceGenerator` 生成文件
- `lib/src/generators/service_generator.dart`：核心生成器，使用 `code_builder` 构造 AST
- `test/golden/golden_test.dart`：golden 测试，对比生成输出与基线文件

## Goals / Non-Goals

**Goals:**
- 新增 `MockServiceGenerator`：生成 `*_mock.dart`，包含 `@GenerateNiceMocks([MockXxxService])` 注解
- 新增 `ExampleTestGenerator`：生成 `*_example_test.dart`，包含基础测试 group + stub 模板
- 修改 `CodeGenerator.generate()`：每个服务额外输出 mock 和 example_test 文件
- 新增 `mock` 插件参数（默认 `true`），控制是否生成
- 新增 golden 测试覆盖

**Non-Goals:**
- 不生成完整测试套件（仅示例模板）
- 不修改已有 service 生成逻辑（仅追加输出）
- 不引入新的运行时依赖
- 不处理 OpenAPI/Swagger 导出

## Decisions

### 1. Mock 生成方案：mockito @GenerateNiceMocks

**选择**：生成 `@GenerateNiceMocks` 注解文件，由用户项目通过 `build_runner` 生成最终 Mock 类。

**理由**：
- 与 Dart/Flutter 生态标准一致，开发者熟悉
- 生成的 mock 文件轻量（仅注解），不引入 mockito 运行时依赖到生成器
- 支持所有流式类型（Unary/Server Streaming）

**替代方案**：手写 Mock 类（零依赖）— 被拒绝，因为功能有限且维护成本高。

### 2. 文件输出策略：独立文件

**选择**：`*_mock.dart` 和 `*_example_test.dart` 作为独立文件输出，与 `*_service.dart` 并列。

**理由**：
- 职责清晰，service 文件不含测试代码
- 用户可选择性忽略 mock 文件
- 符合项目"单文件生成"原则（每个产物独立完整）

### 3. 生成器架构：独立 Generator 类

**选择**：新增 `MockServiceGenerator` 和 `ExampleTestGenerator` 类，遵循 `ServiceGenerator` 模式。

**理由**：
- 与现有架构一致，易于维护
- 每个生成器职责单一
- 便于独立测试

### 4. 插件参数：mock=true

**选择**：新增 `mock` 参数，默认 `true`。

**理由**：
- 向后兼容（默认开启，用户可关闭）
- 与其他参数（`format`, `lint`, `tracing`）风格一致

## Risks / Trade-offs

- **mockito 版本兼容性** → 生成的注解代码保持最小化，仅使用 `@GenerateNiceMocks`，不依赖特定 mockito API
- **Server Streaming mock 复杂性** → Mock 方法返回 `Stream<T>`，示例测试中使用 `Stream.value()` 提供 stub 数据
- **golden 文件维护** → 新增两个 golden 文件，需随生成器变更同步更新

## Migration Plan

无迁移影响。新增功能，不修改已有生成逻辑。

## Open Questions

（无）
