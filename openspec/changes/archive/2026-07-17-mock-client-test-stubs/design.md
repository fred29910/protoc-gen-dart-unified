## Context

`protoc-gen-dart-unified` 已完成 P1-P3 全部功能（MVP 核心、服务治理与观测、流式传输）。当前 `ServiceGenerator` 为每个 proto 服务生成单文件 `*_service.dart`，包含抽象接口 + Unified 实现 + ApiSdk 入口。

Phase 4 需要补充测试生态：自动生成 Mock 客户端和示例测试模板，让开发者无需手写 mock 即可单元测试。

现有代码结构：
- `lib/src/generator.dart`：主入口，遍历 services 调用 `ServiceGenerator` 生成文件
- `lib/src/generators/service_generator.dart`：核心生成器，使用 `code_builder` 构造 AST
- `test/golden/golden_test.dart`：golden 测试，对比生成输出与基线文件

## Goals / Non-Goals

**Goals:**
- 新增 `MockServiceGenerator`：生成 `*_service.dart` 同级的 `*_mock.dart`，以 `class MockXxxService extends Mock implements XxxService {}` 实现（mockito 虚拟 mock，无需 build_runner）
- 新增 `ExampleTestGenerator`：生成 `*_example_test.dart`，包含基础测试 group + **注释形式的** stub 模板
- 修改 `CodeGenerator.generate()`：每个服务额外输出 mock 和 example_test 文件
- 新增 `mock` 插件参数（默认 `true`），控制是否生成
- 新增 golden 测试覆盖

**Non-Goals:**
- 不生成完整测试套件（仅示例模板）
- 不修改已有 service 生成逻辑（仅追加输出）
- 不引入新的运行时依赖
- 不处理 OpenAPI/Swagger 导出

## Decisions

### 1. Mock 生成方案：mockito `extends Mock`

**选择**：生成 `class MockXxxService extends Mock implements XxxService {}`，直接继承 mockito 的 `Mock` 基类（虚拟 mock）。

**理由**：
- 无需 `@GenerateNiceMocks` 注解与 `build_runner` 代码生成步骤，用户项目零额外构建配置
- 生成的 mock 文件自包含、可直接 `dart analyze` 通过
- mockito 的 `Mock` 通过 `noSuchMethod` 虚拟支持所有方法（含 `Stream<T>` 流式返回），无需手写 stub
- 与项目"单文件生成、无运行时依赖注入生成器"原则一致

**替代方案**：`@GenerateNiceMocks` + `build_runner` 代码生成 — 已废弃（提交 f34e0e1），因引入额外构建步骤且需 `mockito/annotations.dart` 生成文件，维护成本高于收益。

### 1b. 示例测试 stub 策略：注释模板

**选择**：示例测试中的 `when(...).thenAnswer(...)` stub 以注释形式生成（`// when(...)`）。

**理由**：
- 生成的示例测试文件必须可直接 `dart analyze` 通过且 `main()` 可运行（空 test 通过），不依赖真实后端
- 用户按需取消注释即可激活 stub，避免生成即强制绑定 mockito 行为
- 与 `extends Mock` 虚拟 mock 配合：stub 仅在使用时才需要

**替代方案**：生成激活的 `when().thenAnswer()` — 被拒绝，因为会强制引入 mockito 运行时行为且示例测试无法在缺少 backend 的情况下直接通过

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

- **mockito 版本兼容性** → 生成的 mock 文件仅依赖 `mockito/mockito.dart` 的 `Mock` 基类，不依赖 `@GenerateNiceMocks` 或 `annotations` 包
- **Server Streaming mock 复杂性** → `Mock` 虚拟支持 `Stream<T>`；示例测试中以注释模板 `// when(...).thenAnswer((_) => Stream.value(...))` 提供
- **golden 文件维护** → 新增两个 golden 文件，需随生成器变更同步更新

## Migration Plan

无迁移影响。新增功能，不修改已有生成逻辑。

## Open Questions

（无）
