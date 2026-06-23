# Comet Design Handoff

- Change: mock-client-test-stubs
- Phase: design
- Mode: compact
- Context hash: 343fbec694b9aa32c4bc6f36ef275a4fb4c5360d4920d8113686ce0e58969eeb

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/mock-client-test-stubs/proposal.md

- Source: openspec/changes/mock-client-test-stubs/proposal.md
- Lines: 1-30
- SHA256: 809b6c32d192097da121c5391cb1db5ff95a4d142076b28c60915001f369dad6

```md
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
```

## openspec/changes/mock-client-test-stubs/design.md

- Source: openspec/changes/mock-client-test-stubs/design.md
- Lines: 1-78
- SHA256: 55e579011a760e5a560eed7a78f57065d3b51458f042b2f3bf5bbbaabaae7f2b

```md
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
```

## openspec/changes/mock-client-test-stubs/tasks.md

- Source: openspec/changes/mock-client-test-stubs/tasks.md
- Lines: 1-34
- SHA256: b9d0e4b0b969ade7bdda018f65f5ce59423b27f8e8af721c10c16d56844e61e0

```md
## 1. Mock 客户端生成器实现

- [ ] 1.1 创建 `lib/src/generators/mock_service_generator.dart`，实现 `MockServiceGenerator` 类，使用 `code_builder` 生成 `@GenerateNiceMocks` 注解的 mock 文件
- [ ] 1.2 支持 Unary 方法的 mock 生成（`Future<T>` 返回类型）
- [ ] 1.3 支持 Server Streaming 方法的 mock 生成（`Stream<T>` 返回类型）
- [ ] 1.4 生成的 mock 文件包含正确的 import（mockito/annotations.dart、pb.dart、service.dart）

## 2. 示例测试生成器实现

- [ ] 2.1 创建 `lib/src/generators/example_test_generator.dart`，实现 `ExampleTestGenerator` 类，生成 `*_example_test.dart` 文件
- [ ] 2.2 生成的测试文件包含 `main()` + `group('XxxService', ...)` 结构
- [ ] 2.3 为每个 Unary 方法生成 `when(...).thenAnswer((_) async => ...)` stub 模板
- [ ] 2.4 为每个 Server Streaming 方法生成 `when(...).thenAnswer((_) => Stream.value(...))` stub 模板
- [ ] 2.5 生成的测试文件包含正确的 import（test、mock、service、pb.dart）

## 3. 主生成器集成

- [ ] 3.1 修改 `lib/src/generator.dart` 的 `CodeGenerator.generate()`，在生成 service 文件后额外调用 `MockServiceGenerator` 和 `ExampleTestGenerator`
- [ ] 3.2 新增 `mock` 插件参数解析（默认 `true`），当 `mock=false` 时跳过 mock 和测试文件生成
- [ ] 3.3 修改 `bin/protoc_gen_dart_unified.dart` 入口以支持 `mock` 参数传递

## 4. Golden 测试

- [ ] 4.1 新增 `test/goldens/user_service_mock.dart.golden` — Mock 文件的期望输出
- [ ] 4.2 新增 `test/goldens/user_service_example_test.dart.golden` — 示例测试文件的期望输出
- [ ] 4.3 修改 `test/golden/golden_test.dart`，新增 mock 和 example_test 的 golden 测试用例
- [ ] 4.4 运行 `UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart` 生成 golden 文件

## 5. 验证与收尾

- [ ] 5.1 运行完整测试套件 `dart test`，确保所有测试通过
- [ ] 5.2 运行 `dart analyze`，确保零错误
- [ ] 5.3 验证生成的 mock 文件可被 `dart analyze` 分析通过
- [ ] 5.4 更新 `docs/design.md` Phase 4 状态为已完成
```

## openspec/changes/mock-client-test-stubs/specs/example-test-stub-generation/spec.md

- Source: openspec/changes/mock-client-test-stubs/specs/example-test-stub-generation/spec.md
- Lines: 1-37
- SHA256: 20cd29ff75f228b83e377f542beb2f3524a554d65d1958eabb048d8471dc3a6d

```md
## ADDED Requirements

### Requirement: Generator SHALL produce an example test file for each service

For every service defined in the proto file, the generator SHALL produce a `*_example_test.dart` file in the same output directory. The example test file SHALL contain a test group for each service method with a basic stub template.

#### Scenario: Example test file has correct structure
- **WHEN** the generator creates an example test file for `UserService` with methods `getUser` and `createUser`
- **THEN** the file contains a `main()` function with `group('UserService', ...)` containing test stubs for each method

#### Scenario: Example test imports required dependencies
- **WHEN** the generator creates an example test file
- **THEN** the file imports `package:test/test.dart`, the mock file, and the service file

#### Scenario: mock=false disables example test generation
- **WHEN** the `mock` plugin parameter is set to `false`
- **THEN** the generator does NOT produce `*_example_test.dart` files

### Requirement: Example test SHALL include stub templates for each method

For each unary method, the example test SHALL include a `test()` block with `when(...).thenReturn(...)` stub template. For server streaming methods, the stub SHALL use `Stream.value()`.

#### Scenario: Unary method stub template
- **WHEN** the service has a unary method `getUser(GetUserRequest) → Future<User>`
- **THEN** the example test contains a test block with `when(mockUserService.getUser(any)).thenAnswer((_) async => User())`

#### Scenario: Server streaming method stub template
- **WHEN** the service has a server streaming method `watchUser(GetUserRequest) → Stream<User>`
- **THEN** the example test contains a test block with `when(mockUserService.watchUser(any)).thenAnswer((_) => Stream.value(User()))`

### Requirement: Example test file SHALL be formatted and lint-free

The generated example test file SHALL be formatted with `DartFormatter` and pass `dart analyze` with zero errors.

#### Scenario: Example test file passes dart analyze
- **WHEN** the generator produces an example test file
- **THEN** the file can be analyzed with `dart analyze` without errors (assuming user has test + mockito dependencies)
```

## openspec/changes/mock-client-test-stubs/specs/mock-client-generation/spec.md

- Source: openspec/changes/mock-client-test-stubs/specs/mock-client-generation/spec.md
- Lines: 1-37
- SHA256: 362753735af60e319a2f5b9b751c5d21dca4f4ddb74fef65d88d99fecaa9c5fb

```md
## ADDED Requirements

### Requirement: Generator SHALL produce a mock client file for each service

For every service defined in the proto file, the generator SHALL produce a `*_mock.dart` file in the same output directory as the `*_service.dart` file. The mock file SHALL contain a `@GenerateNiceMocks` annotation targeting a class that implements the abstract service interface.

#### Scenario: Unary service generates mock file
- **WHEN** a proto service has only unary methods (no streaming)
- **THEN** the generator produces `*_mock.dart` containing `@GenerateNiceMocks([MockXxxService])` where `MockXxxService` implements the abstract `XxxService` interface

#### Scenario: Service with server streaming generates mock file
- **WHEN** a proto service has server streaming methods
- **THEN** the generator produces `*_mock.dart` with mock methods returning `Stream<T>` for server streaming methods

#### Scenario: mock=false disables mock generation
- **WHEN** the `mock` plugin parameter is set to `false`
- **THEN** the generator does NOT produce `*_mock.dart` files

### Requirement: Mock file SHALL follow mockito conventions

The generated mock file SHALL import `package:mockito/annotations.dart` and the service's message types. The mock class name SHALL follow the pattern `MockXxxService` where `XxxService` is the abstract service interface name.

#### Scenario: Mock file has correct imports
- **WHEN** the generator creates a mock file for `UserService`
- **THEN** the file imports `package:mockito/annotations.dart` and `../user.pb.dart` (for message types)

#### Scenario: Mock class implements service interface
- **WHEN** the abstract service interface is `UserService`
- **THEN** the generated mock class is `class MockUserService implements UserService`

### Requirement: Mock file SHALL be formatted and lint-free

The generated mock file SHALL be formatted with `DartFormatter` and pass `dart analyze` with zero errors.

#### Scenario: Mock file passes dart analyze
- **WHEN** the generator produces a mock file
- **THEN** the file can be analyzed with `dart analyze` without errors
```

