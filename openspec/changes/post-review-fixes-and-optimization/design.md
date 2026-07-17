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

**Decision**: 在生成的 Dart 代码中使用 `switch` + 索引模式处理 oneof 互斥语义。

**Rationale**:
- protobuf 的 oneof 在 `DescriptorProto` 中通过 `oneof_decl` 和 `oneof_index` 表示
- Dart 端的 `protobuf` 库生成的代码已经为 oneof 字段生成 `hasField()` 和 `getField()` 方法
- 生成器层面不生成 oneof 逻辑的运行时校验，仅在抽象接口层面暴露正确的类型签名
- 生成器在代码中为每个 oneof 组生成清晰的 Dart 映射模式

**实现方式**:
```dart
// 解析时读取 oneof_index
final oneofIndex = f.hasOneofIndex() ? f.oneofIndex : null;
final oneofName = oneofIndex != null 
    ? d.oneofDecl[oneofIndex].name 
    : null;
```

### D3: enum 映射策略

**Decision**: 在当前解析层增加 enum 提取逻辑，生成 Dart 枚举常量。

**Rationale**:
- `EnumDescriptorProto` 存在于 `file.enumType` 列表中
- 需要在 `MessageModel` 中添加枚举列表（`List<EnumModel>`）
- 枚举值映射为 Dart `enum` 类型

```dart
class EnumModel {
  final String name;
  final List<EnumValueModel> values;
}

class EnumValueModel {
  final String name;     // Proto 名称（如 ENUM_TYPE_UNSPECIFIED）
  final int number;      // Proto 编号
  final String dartName; // Dart 驼峰名称（如 enumTypeUnspecified）
}
```

### D4: map 精准检测策略

**Decision**: 使用 protobuf 标准规则（entry message naming convention）替代当前宽泛的检测。

**Rationale**:
- Proto3 中 map 字段对应的 message 命名规则为 `{MapFieldName}Entry`
- 该 message 有 `key` 和 `value` 两个字段
- 检测 `isMap` 时只需要检查 `f.typeName` 的后缀是否为 `Entry` 即可（通过 `f.type` 为 `TYPE_MESSAGE` 为前提）

```dart
// 解析逻辑
bool isMapField(FieldDescriptorProto f, List<DescriptorProto> messages) {
  if (f.type != FieldDescriptorProto_Type.TYPE_MESSAGE) return false;
  // 查找该类型对应的 DescriptorProto 来判断是否为 map entry
  final entryMsg = messages.where((m) => m.name == _stripTypeName(f.typeName));
  return entryMsg.any((m) => 
    m.field.length == 2 &&
    m.field[0].name == 'key' &&
    m.field[1].name == 'value'
  );
}
```

### D5: gRPC 客户端类型安全

**Decision**: 引入泛型接口 `GrpcClient` 替代 `dynamic`。

**Rationale**:
- 当前使用 `dynamic` 是因为 gRPC 生成客户端（`protoc-gen-dart`）的接口类型不确定
- 更彻底的方案是定义一个抽象接口
- 但当前阶段采用更务实的方式：将 `_grpcClient` 改为 `Object?` 类型，并在生成的代码中使用类型安全的包装方法

```dart
// 生成代码中使用类型安全包装
T _grpcCall<T>(Future<T> Function() call) {
  return call();
}

// 生成的实现方法中
return _grpcCall(() => (_grpcClient as dynamic).$methodName(request));
```

实际上，更彻底的方案是让 gRPC 传输层支持泛型调用。但从兼容性考虑，当前先使用 `Object?` + 运行时类型断言，标记为后续改进。

### D6: 生成器注册表

**Decision**: 在 `CodeGenerator` 中引入 `Map<String, ServiceGenerator>` 注册表。

**Rationale**:
- 当前硬编码的 `ServiceGenerator`、`MockServiceGenerator`、`ExampleTestGenerator` 创建逻辑
- 注册表模式允许外部通过配置或 SPI 机制注册新的生成器

```dart
abstract class Generator {
  String get outputSuffix;  // e.g., '.dart', '_mock.dart'
  String generate(ServiceModel service);
}

class CodeGenerator {
  final Map<String, Generator> _generators = {};
  
  void register(String key, Generator generator) {
    _generators[key] = generator;
  }
}
```

### D7: 并行生成

**Decision**: 使用 `Future.wait` + Isolate 池并行处理服务生成。

**Rationale**:
- 每个服务的生成是独立的，天然可并行
- 使用 `Isolate.run()` 在独立 Isolate 中执行生成，不阻塞主 Isolate
- 相比 `Future.wait` + 异步，Isolate 模式可以真正利用多核 CPU

```dart
Future<List<CodeGeneratorResponse_File>> _generateInParallel(
  List<ServiceModel> services,
) async {
  final results = await Future.wait(
    services.map((s) => Isolate.run(() => _generateService(s))),
  );
  return results.expand((r) => r).toList();
}
```

### D8: 错误信息分层

**Decision**: 引入 `GenerationException` 异常层次结构，按类别分类。

```dart
sealed class GenerationException implements Exception {
  final String message;
  final String? location;
}

class ParseException extends GenerationException { ... }
class ValidationException extends GenerationException { ... }
class InternalException extends GenerationException { ... }
```

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| oneof 字段在现有 protobuf 生成代码中的兼容性 | 参考 protobuf.dart 库的 GeneratedMessage 基类中的 `_oneofs` 字段 |
| map 类型检测的假阳性 | 采用双层检测：type=TYPE_MESSAGE + 检查 entry message 结构 |
| Isolate 并行化的上下文传输成本 | 对于小服务集合（<10），串行可能更快；设计为可选启用 |
| 注册表模式增加启动复杂度 | 保持简单 Map 注册，不引入 SPI 或反射机制 |
| enum Dart 命名与 proto 命名的冲突 | 实现 `_toDartEnumName()` 处理 `ENUM_TYPE_UNSPECIFIED` → `enumTypeUnspecified` |
| 运行时内联提取为独立文件后需要版本同步 | 在 `RuntimeInlineGenerator` 中保留版本号，生成头部包含版本注释 |

## Open Questions

1. `protobuf.dart` 库中 oneof 字段的具体表示方式是什么？需要阅读 `GeneratedMessage` 源码确认 `_oneofs` 和 `_oneofFields` 的行为。
2. 当前测试框架中的 `_buildUserProtoFile()` 能否支持 oneof/enum/map 的构建？可能需要扩展测试工具函数。
3. 生成器注册表是否需要支持基于配置的启用/禁用？
