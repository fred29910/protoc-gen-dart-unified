# Comet Design Handoff

- Change: post-review-fixes-and-optimization
- Phase: design
- Mode: compact
- Context hash: dbf60a928c0283d739ea32fef412258011b9444a3087cddc1e8e1043efca3d3c

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/post-review-fixes-and-optimization/proposal.md

- Source: openspec/changes/post-review-fixes-and-optimization/proposal.md
- Lines: 1-49
- SHA256: 7df6df861c8fffe34ce26fb3838fcacfe21bb12f2eacdf58e5104355e1fb06df

```md
## Why

protoc-gen-dart-unified 已通过完整技术审计与代码评审，识别出若干关键缺陷：Protobuf 协议兼容性不足（缺失 `oneof`/`map`/`enum` 处理）、gRPC 客户端使用 `dynamic` 类型存在运行时崩溃风险、缺乏输入验证导致生成代码质量不可靠、以及工程鲁棒性方面的内存和错误处理缺陷。当前修复这些问题是确保生成器可用于生产环境的前提。

## What Changes

### 高优先级（H1-H5）

- **H1 — gRPC 客户端类型安全**：将 `_grpcClient` 从 `dynamic` 替换为具体 gRPC 客户端类型签名，消除运行时类型转换风险
- **H2 — `oneof` 字段支持**：扩展 `FieldModel` 添加 `oneofName`/`oneofFields`，在生成代码中正确处理 oneof 互斥语义
- **H3 — `enum` 类型映射**：扩展 `FieldModel` 添加 `isEnum`/`enumValues`，在解析层准确提取 enum 信息并生成类型安全的 Dart 枚举映射
- **H4 — `map` 类型精准检测**：修复 `isMap` 检测逻辑，精确区分 map 消息和普通嵌套消息，提取键值类型
- **H5 — 输入验证**：添加方法名冲突检测、类型存在性验证、空服务名处理、保留字冲突检测

### 中优先级（M1-M6）

- **M1 — 运行时代码独立**：将 `RuntimeInlineGenerator` 的 837 行内联字符串提取为独立模板文件
- **M2 — 生成器注册表**：引入 `Map<String, Generator>` 注册机制替代硬编码调度
- **M3 — 流式内存输出**：优化内存模型支持流式输出，避免全量内存存储
- **M4 — 并行生成**：使用 Dart Isolate 并行处理多个服务的代码生成
- **M5 — 错误信息改进**：按错误类型分类返回，附带精确位置和上下文
- **M6 — 文档注释**：为生成的类和方法生成 `///` 文档注释

### 低优先级（L1-L5）

- 增量生成支持、进度反馈、资源限制、序列化性能优化、Well-Known Types 特殊处理（本次暂不涉及）

## Capabilities

### New Capabilities

- `oneof-field-support`: 为 FieldModel 增加 oneof 元数据，生成器在生成代码时正确处理互斥字段的序列化/反序列化逻辑
- `enum-type-mapping`: 从 proto 描述符中提取 enum 定义，映射为 Dart 枚举类型，支持 enum 的字符串表示和序列化
- `map-type-detection`: 精确识别 protobuf map 类型字段，提取键值类型信息供生成器正确生成 map 序列化代码
- `input-validation`: 在代码生成入口处进行输入有效性验证，包括方法名/消息名冲突、类型存在性、空输入等边界情况
- `type-safe-grpc-client`: 消除 gRPC 客户端的 dynamic 类型使用，引入泛型或接口类型约束

### Modified Capabilities

- `code-generation-pipeline`: 代码生成管道增加生成器注册表模式、并行调度能力和流式输出机制
- `error-handling`: 错误处理系统从单一 catch-all 升级为按类型分类的可追溯错误报告

## Impact

- **Parser Layer** (`descriptor_parser.dart`): 扩展解析逻辑以提取 oneof/enum/map 元数据
- **Model Layer** (`field_model.dart`, `message_model.dart`): 增加 oneof/enum/map 字段和新模型类
- **Generator Layer** (`service_generator.dart`, `generator.dart`): 类型安全优化、注册表机制、并行化
- **Runtime Layer** (`runtime_inline_generator.dart`): 提取为独立文件（M1）
- **Tests**: 现有 golden 测试需更新，新增 `oneof`/`map`/`enum` 测试用例
```

## openspec/changes/post-review-fixes-and-optimization/design.md

- Source: openspec/changes/post-review-fixes-and-optimization/design.md
- Lines: 1-237
- SHA256: 65dc45284f42b45da0eb18796707990bd89ffda67fec28ac1ed173325ca4bac6

[TRUNCATED]

```md
## Context

protoc-gen-dart-unified 当前实现了基础的 Proto3 代码生成能力，但存在类型安全、协议兼容性和工程鲁棒性方面的缺陷。技术审计报告 `docs/reviews/technical_review_report.md` 详尽记录了这些问题。本设计文档覆盖 H1-H5 高优先级修复和 M1-M6 中优先级优化的技术方案。

### 当前架构核心问题

```
    ┌──────────────────────────────────────────────────┐
    │                 FieldModel                       │
    │  +name    +type    +isRepeated  +isOptional      │
    │  +isMap   +messageType                           │
    │  ❌ 缺少: oneofName, oneofFields, isEnum,        │
    │      enumValues, mapKeyType, mapValueType         │
    └──────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────┐
    │              ServiceGenerator                    │
    │  _grpcClient : dynamic    ← 类型不安全            │
    │  ❌ 缺少输入验证                                  │
    └──────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────┐
    │              CodeGenerator                       │
    │  for (service in services) {  ← 串行处理          │
    │    files.add(content);        ← 全量内存存储      │
    │  }                                                │
    └──────────────────────────────────────────────────┘
```

## Goals / Non-Goals

**Goals:**
- 实现 `oneof` 字段的完整解析与代码生成支持
- 实现 `enum` 类型的正确解析与 Dart enum 映射
- 实现 `map` 类型的精准检测与键值类型提取
- 消除 gRPC 客户端中的 `dynamic` 类型使用
- 添加代码生成输入验证（方法名冲突、类型存在性、空输入）
- 提取运行时内联代码为独立模板文件
- 引入生成器注册表模式
- 实现并行生成和流式输出
- 改进错误信息质量

**Non-Goals:**
- 不引入新的传输协议支持
- 不重写核心代码生成引擎
- 不修改 `unified_runtime.dart` 的运行时行为
- 本次不做 L1-L5 低优先级优化

## Decisions

### D1: FieldModel 扩展策略

**Decision**: 在现有 `FieldModel` 中添加可选字段，不创建专门的子类。

**Rationale**:
- `FieldModel` 当前已在 `descriptor_parser.dart`、`http_mapper.dart`、`service_generator.dart` 中广泛使用
- 新增 `oneofName`、`isEnum` 等字段为 `String?`/`bool` 类型，不会破坏现有使用模式
- 相比创建 `OneofFieldModel`、`EnumFieldModel` 等子类，保持单一模型类可以最小化下游影响
- 新增字段均设为可选（nullable），现有代码不受影响

```dart
class FieldModel {
  final String name;
  final String type;
  final bool isRepeated;
  final bool isOptional;
  final bool isMap;
  final String? messageType;
  
  // 新增字段
  final String? oneofName;          // 所属 oneof 组名（非空时表示该字段属于 oneof）
  final bool isEnum;                // 是否为枚举类型
  final List<String>? enumValues;   // 枚举值列表（当 isEnum 为 true 时）
  final String? mapKeyType;         // map 键类型（当 isMap 为 true 时）
  final String? mapValueType;       // map 值类型（当 isMap 为 true 时）
}
```

### D2: oneof 代码生成策略

```

Full source: openspec/changes/post-review-fixes-and-optimization/design.md

## openspec/changes/post-review-fixes-and-optimization/tasks.md

- Source: openspec/changes/post-review-fixes-and-optimization/tasks.md
- Lines: 1-56
- SHA256: a118e025377e66a871bdf6427cd903b6d1b7ee2f611701e3e1838a17cd22cbee

```md
## 1. 模型层扩展（Model Layer）

- [ ] 1.1 扩展 `FieldModel`：添加 `oneofName` (String?)、`isEnum` (bool)、`enumValues` (List\<String>?)、`mapKeyType` (String?)、`mapValueType` (String?) 字段
- [ ] 1.2 创建 `EnumModel` 和 `EnumValueModel` 类，用于表示 proto enum 定义
- [ ] 1.3 在 `MessageModel` 中添加 `enums` (List\<EnumModel>) 字段，支持消息内嵌枚举
- [ ] 1.4 更新现有构造器和 `const` 构造函数，新增字段均为可选默认值

## 2. 解析层增强（Parser Layer）

- [ ] 2.1 `descriptor_parser.dart`：扩展 `_parseMessages()` 提取 `oneof_decl`/`oneof_index` → `FieldModel.oneofName`
- [ ] 2.2 `descriptor_parser.dart`：提取 `EnumDescriptorProto` → `EnumModel` 映射，处理 proto → Dart 命名转换（ENUM_TYPE_UNSPECIFIED → enumTypeUnspecified）
- [ ] 2.3 `descriptor_parser.dart`：实现精准 map 类型检测（检查 type=TYPE_MESSAGE + entry message 含 key/value 字段），提取 mapKeyType/mapValueType
- [ ] 2.4 `descriptor_parser.dart`：扩展 `parse()` 方法，将 enum 类型注册到 `MessageModel.enums` 中
- [ ] 2.5 `MessageModel`：在 `_parseMessages` 完成后将 enum 列表与对应 message 关联

## 3. gRPC 类型安全修复（Type Safety）

- [ ] 3.1 `service_generator.dart`：将 `_grpcClient` 字段类型从 `dynamic` 改为 `Object?`
- [ ] 3.2 `service_generator.dart`：添加类型安全的 gRPC 流式委托辅助方法
- [ ] 3.3 `service_generator.dart`：HTTP-only 服务不生成 `_grpcClient` 字段

## 4. 输入验证（Input Validation）

- [ ] 4.1 创建 `lib/src/parser/input_validator.dart`：实现服务方法名唯一性验证（case-insensitive）
- [ ] 4.2 实现消息类型存在性验证：检查 `inputType`/`outputType` 是否在 `protoFile` 中定义
- [ ] 4.3 实现保留字冲突检测：Dart 保留字（class, import, default 等）冲突处理
- [ ] 4.4 实现空输入处理：空服务名、空方法列表、空消息 → 返回正确结果或精确错误
- [ ] 4.5 `generator.dart`：集成 `InputValidator`，在 `parse()` 之后、生成之前执行验证

## 5. 生成器管道优化（Pipeline）

- [ ] 5.1 引入 `Generator` 抽象接口和 `Map<String, Generator>` 注册表
- [ ] 5.2 将 `ServiceGenerator`/`MockServiceGenerator`/`ExampleTestGenerator` 适配到注册表模式
- [ ] 5.3 实现并行生成支持：使用 `Future.wait` + `Isolate.run` 并行处理多服务
- [ ] 5.4 实现流式输出模式：可选分批输出生成结果，降低峰值内存

## 6. 运行时代码提取

- [ ] 6.1 `RuntimeInlineGenerator`：将内联字符串模板提取到 `lib/src/runtime/inline/` 目录中的独立文件
- [ ] 6.2 添加版本号同步机制，确保生成器版本与运行时版本一致

## 7. 错误报告改进

- [ ] 7.1 创建 `GenerationException` 密封类层次结构（ParseException/ValidationException/InternalException）
- [ ] 7.2 `generator.dart`：按异常类型分类错误信息，附带文件/行号/模块上下文
- [ ] 7.3 `descriptor_parser.dart`：将 `StateError` 替换为精确异常类型

## 8. 测试与验证

- [ ] 8.1 编写 `oneof` 解析和代码生成的单元测试：`FieldModel.oneofName` 提取验证
- [ ] 8.2 编写 `enum` 解析和 Dart enum 生成的测试
- [ ] 8.3 编写 `map` 精准检测的测试（正例 + 反例）
- [ ] 8.4 编写输入验证测试：方法名冲突、类型缺失、空输入、保留字冲突
- [ ] 8.5 编写 gRPC 客户端类型安全测试
- [ ] 8.6 更新 golden 测试：现有 golden 文件可能需更新，新增 `oneof`/`enum`/`map` fixture
- [ ] 8.7 运行完整测试套件：`dart test` + `dart analyze --fatal-infos`
```

## openspec/changes/post-review-fixes-and-optimization/specs/code-generation-pipeline/spec.md

- Source: openspec/changes/post-review-fixes-and-optimization/specs/code-generation-pipeline/spec.md
- Lines: 1-43
- SHA256: 8eb4b90d1f8e8eac75b3797526624ea85bebeda131ecd32d6fc6ffb51389c901

```md
## ADDED Requirements

### Requirement: Generator registry mechanism

The system SHALL provide a `Map<String, Generator>` registry allowing generators to be registered by key, replacing hardcoded generator instantiation in `CodeGenerator.generate()`.

#### Scenario: register and invoke a generator
- **WHEN** a `Generator` is registered with key `'service'`
- **THEN** passing key `'service'` to the generator registry SHALL return the generator instance
- **THEN** calling `generate()` on the returned instance SHALL produce valid generated output

#### Scenario: unknown generator key returns null
- **WHEN** a key that has not been registered is requested
- **THEN** the registry SHALL return `null` (not throw)

### Requirement: Parallel service generation

The system SHALL support generating multiple service files in parallel using Dart concurrency primitives.

#### Scenario: parallel generation produces same output as sequential
- **WHEN** generating N services in parallel mode
- **THEN** the set of output files SHALL be identical to sequential generation

#### Scenario: parallel generation handles errors gracefully
- **WHEN** one service fails during parallel generation
- **THEN** the error SHALL be collected and reported without crashing other services

### Requirement: Streaming output model

The system SHALL support incremental output delivery to avoid holding all generated files in memory simultaneously.

#### Scenario: large service set generates incrementally
- **WHEN** generating 50+ services with streaming output enabled
- **THEN** peak memory usage SHALL NOT exceed the size of the largest single generated file by more than 50%

### Requirement: Concurrent-safe Input validation

Input validation SHALL run before service generation and SHALL be safe under concurrent access.

#### Scenario: validation runs before parallel dispatch
- **WHEN** parallel generation is enabled
- **THEN** validation SHALL complete before dispatching any services to generators
- **THEN** invalid input SHALL short-circuit the entire generation with a clear error
```

## openspec/changes/post-review-fixes-and-optimization/specs/enum-type-mapping/spec.md

- Source: openspec/changes/post-review-fixes-and-optimization/specs/enum-type-mapping/spec.md
- Lines: 1-33
- SHA256: 6bc5b1741f68a91787771e17e946580ef35587d2605f57d243f0f54466552eaa

```md
## ADDED Requirements

### Requirement: Parser extracts EnumDescriptorProto definitions

The system SHALL extract `EnumDescriptorProto` entries from `FileDescriptorProto.enumType` and store them in a new `EnumModel` class.

#### Scenario: enum type is parsed from proto descriptor
- **WHEN** a `.proto` file defines an `enum` with multiple values
- **THEN** the parser SHALL extract each enum value name, number, and generate a compliant Dart enum name

#### Scenario: enum with aliased values
- **WHEN** an enum has `allow_alias` option set and duplicate numeric values
- **THEN** the parser SHALL extract all aliased names

### Requirement: Dart enum generation from proto enum

The generated Dart code SHALL produce a valid Dart `enum` type for each proto `enum` definition.

#### Scenario: basic enum generation
- **WHEN** a proto enum `Color { COLOR_RED = 0; COLOR_GREEN = 1; COLOR_BLUE = 2; }` is processed
- **THEN** generated Dart code SHALL contain `enum Color { colorRed, colorGreen, colorBlue; }`

#### Scenario: enum with default value (0)
- **WHEN** the first enum value is `ENUM_TYPE_UNSPECIFIED = 0` (proto3 default)
- **THEN** generated Dart enum SHALL include this value for wire compatibility

### Requirement: Generated code uses concrete Dart enum types

The system SHALL reference generated Dart `enum` types in service method signatures where enum fields appear in request/response messages.

#### Scenario: enum field in method signature
- **WHEN** a message field is of enum type
- **THEN** the generated service interface method SHALL use the Dart `enum` type (not `int` or `String`)
```

## openspec/changes/post-review-fixes-and-optimization/specs/input-validation/spec.md

- Source: openspec/changes/post-review-fixes-and-optimization/specs/input-validation/spec.md
- Lines: 1-59
- SHA256: ffac240b94c852bcafacf4b0edf32eeedb096306956007196e9d33a171247660

```md
## ADDED Requirements

### Requirement: Method name uniqueness validation

The system SHALL validate that no two methods within the same service share the same name (case-insensitive for Dart compatibility).

#### Scenario: duplicate method names detected
- **WHEN** a proto service defines two methods with names differing only by case (e.g., `getUser` and `GetUser`)
- **THEN** the generator SHALL return a precise error indicating the conflict

#### Scenario: unique method names pass validation
- **WHEN** all methods in a service have unique names
- **THEN** generation SHALL proceed normally

### Requirement: Message type existence validation

The system SHALL validate that all referenced input and output types in service methods exist as defined messages or well-known types.

#### Scenario: missing input type
- **WHEN** a method references an input type that is not defined in any proto file
- **THEN** the generator SHALL return an error with the method name and missing type

#### Scenario: all types exist
- **WHEN** all referenced types are defined in the proto files
- **THEN** generation SHALL proceed normally

### Requirement: Empty input handling

The system SHALL handle empty or minimal inputs without crashing.

#### Scenario: empty service (no methods)
- **WHEN** a proto file defines a service with zero methods
- **THEN** the generator SHALL produce a valid (empty) interface file

#### Scenario: empty message (no fields)
- **WHEN** a proto file defines a message with no fields
- **THEN** the parser SHALL produce a valid `MessageModel` with an empty field list

### Requirement: Reserved word conflict detection

The system SHALL detect when proto identifiers conflict with Dart reserved words and provide a warning or automatic mangling.

#### Scenario: field name is a Dart reserved word
- **WHEN** a proto field is named `class`, `import`, `default`, or other Dart reserved words
- **THEN** the generator SHALL mangle the name (e.g., `class_` suffix) or report an error

## MODIFIED Requirements

### Requirement: Error message granularity (previously informal)

The generator SHALL produce structured error messages including error type, location, and message.

#### Scenario: parse error includes file and line
- **WHEN** a proto file contains a syntax error
- **THEN** the error SHALL include the file name and line number

#### Scenario: generation error includes module name
- **WHEN** a generator fails during code generation
- **THEN** the error SHALL include which generator module failed
```

## openspec/changes/post-review-fixes-and-optimization/specs/map-type-detection/spec.md

- Source: openspec/changes/post-review-fixes-and-optimization/specs/map-type-detection/spec.md
- Lines: 1-27
- SHA256: abaca63c036dd94a78a0405c72eac23378c8f83443bea7db8a56464a9c2af802

```md
## ADDED Requirements

### Requirement: Precise map type detection

The system SHALL detect protobuf `map` fields by verifying the field's type is `TYPE_MESSAGE` and its type name corresponds to a message with exactly two fields named `key` and `value`.

#### Scenario: standard map field detected correctly
- **WHEN** a field is defined as `map<string, int32> tags = 1`
- **THEN** `FieldModel.isMap` SHALL be `true`
- **THEN** `FieldModel.mapKeyType` SHALL be `'string'`
- **THEN** `FieldModel.mapValueType` SHALL be `'int32'`

#### Scenario: non-map TYPE_MESSAGE not misclassified
- **WHEN** a field references a regular message type with more than 2 fields
- **THEN** `FieldModel.isMap` SHALL be `false`

#### Scenario: TYPE_MESSAGE with 2 non-key/value fields
- **WHEN** a field references a message type with 2 fields named differently from `key` and `value`
- **THEN** `FieldModel.isMap` SHALL be `false`

### Requirement: map field serialization in generated code

Generated code SHALL correctly serialize protobuf map fields using `toProto3Json()` for HTTP/JSON transport.

#### Scenario: map fields in HTTP body mapping
- **WHEN** a request message contains map fields and `body: "*"` is used
- **THEN** the generated HTTP body code SHALL include the map fields in serialized JSON
```

## openspec/changes/post-review-fixes-and-optimization/specs/oneof-field-support/spec.md

- Source: openspec/changes/post-review-fixes-and-optimization/specs/oneof-field-support/spec.md
- Lines: 1-34
- SHA256: 270fa3cfeccf01049e3bb97f99fcc362be8a463ad7772ced14ddbd4a6ca2fe91

```md
## ADDED Requirements

### Requirement: Parser extracts oneof metadata from DescriptorProto

The system SHALL extract `oneof_decl` and `oneof_index` from `DescriptorProto` and store the oneof group name in `FieldModel.oneofName`.

#### Scenario: field with oneof_index references valid oneof_decl
- **WHEN** a field has `oneof_index` set to a valid index within `oneof_decl` list
- **THEN** `FieldModel.oneofName` SHALL be set to the corresponding `oneof_decl` name

#### Scenario: field without oneof_index
- **WHEN** a field does not have `oneof_index` set
- **THEN** `FieldModel.oneofName` SHALL be `null`

#### Scenario: oneof field appears in generated abstract interface
- **WHEN** a proto method has a oneof field in its input message
- **THEN** the generated abstract interface SHALL include the oneof field with correct type

### Requirement: FieldModel supports oneof metadata

`FieldModel` SHALL expose a `oneofName` field of type `String?` identifying the oneof group to which the field belongs.

#### Scenario: oneofName is consumed by service generator
- **WHEN** `ServiceGenerator` processes methods with oneof-containing messages
- **THEN** generated code SHALL correctly reference the oneof fields

### Requirement: oneof serialization correctness

Generated code SHALL NOT break protobuf oneof serialization semantics where only one field in a oneof group may be set at a time.

#### Scenario: oneof field set/unset produces correct wire format
- **WHEN** a oneof field is set and then another field in the same group is set
- **THEN** the first field SHALL be cleared per protobuf semantics
- **THEN** the serialized output SHALL contain only the last set field
```

## openspec/changes/post-review-fixes-and-optimization/specs/type-safe-grpc-client/spec.md

- Source: openspec/changes/post-review-fixes-and-optimization/specs/type-safe-grpc-client/spec.md
- Lines: 1-30
- SHA256: 63ed9b0cc662ba720bc69083717aff45bab72be10fb8eb9a28d7f6457c2bc899

```md
## ADDED Requirements

### Requirement: GrpcClient type abstraction

The system SHALL introduce a typed abstraction for gRPC clients, replacing the current `dynamic` type for `_grpcClient` in generated `Unified<Service>` implementations.

#### Scenario: generated unified service uses typed client
- **WHEN** a gRPC-only service implementation is generated
- **THEN** `_grpcClient` field SHALL use `Object?` type instead of `dynamic`
- **THEN** the generated code SHALL include helper casts for gRPC delegation

#### Scenario: HTTP-only service has no grpcClient field
- **WHEN** all methods have `google.api.http` annotations
- **THEN** the generated `Unified<Service>` class SHALL NOT include any `_grpcClient` field

### Requirement: Type-safe streaming delegation

Generated gRPC server streaming methods SHALL type-check stream responses at compile time rather than runtime.

#### Scenario: server stream return type matches service client
- **WHEN** a gRPC server streaming method is generated
- **THEN** the delegation code SHALL cast the gRPC stream result to the correct `Stream<T>` type using a typed helper

### Requirement: Forward-compatible API

The typed abstraction SHALL allow future introduction of a full gRPC transport interface without breaking generated code.

#### Scenario: new grpc transport interface can be added
- **WHEN** a future version introduces `GrpcClient` interface
- **THEN** existing generated code SHALL compile with minimal migration
```

