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
