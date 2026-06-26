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
