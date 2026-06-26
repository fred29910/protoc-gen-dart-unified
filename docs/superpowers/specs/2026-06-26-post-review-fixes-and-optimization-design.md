---
comet_change: post-review-fixes-and-optimization
role: technical-design
canonical_spec: openspec
---

# 技术设计：技术审计修复与优化

## 背景

基于 `docs/reviews/technical_review_report.md` 的完整技术审计，本设计针对 protoc-gen-dart-unified 的 5 项高优先级缺陷（H1-H5）和 6 项中优先级优化（M1-M6）制定实现方案。变更继承 OpenSpec change `post-review-fixes-and-optimization` 的全部范围定义。

## 设计目标

1. 消除 gRPC 客户端的 `dynamic` 类型使用，实现编译期类型安全
2. 覆盖 Proto3 的 oneof/enum/map 特性，提升协议兼容性
3. 建立代码生成输入验证机制，预防无效输入导致的不良输出
4. 优化代码生成管道，引入注册表模式和可选的并行生成

## 架构变更

### 新增文件

| 文件 | 职责 |
|------|------|
| `lib/src/runtime/grpc_client.dart` | `GrpcClient` 抽象接口定义 |
| `lib/src/parser/input_validator.dart` | 输入验证逻辑 |
| `lib/src/model/enum_model.dart` | `EnumModel` / `EnumValueModel` 数据类 |
| `lib/src/parser/enum_parser.dart` | enum 提取与命名转换逻辑 |
| `lib/src/generator/generator_registry.dart` | 生成器注册表 |

### 修改文件

| 文件 | 变更内容 |
|------|---------|
| `lib/src/model/field_model.dart` | 添加 `oneofName`/`isEnum`/`enumValues`/`mapKeyType`/`mapValueType` |
| `lib/src/model/message_model.dart` | 添加 `enums: List<EnumModel>` |
| `lib/src/parser/descriptor_parser.dart` | oneof/enum/map 提取 |
| `lib/src/generators/service_generator.dart` | `GrpcClient` 替代 `dynamic`，oneof 分组生成 |
| `lib/src/generators/runtime_inline_generator.dart` | 提取为独立文件 |
| `lib/src/generator.dart` | 集成 InputValidator + 注册表 + 并行模式 |

### 删除/废弃

- `RuntimeInlineGenerator.generate()` 改为从文件读取，不再使用 837 行内联字符串

## 详细设计方案

### 1. FieldModel 扩展

```dart
class FieldModel {
  // 现有字段
  final String name;
  final String type;
  final bool isRepeated;
  final bool isOptional;
  final bool isMap;
  final String? messageType;

  // 新增字段（均为可选，向后兼容）
  final String? oneofName;           // 所属 oneof 组名
  final bool isEnum;                 // 是否为枚举类型
  final List<String>? enumValues;    // 枚举值列表
  final String? mapKeyType;          // map 键类型
  final String? mapValueType;        // map 值类型
  
  const FieldModel({
    // ... 现有字段 ...
    this.oneofName,
    this.isEnum = false,
    this.enumValues,
    this.mapKeyType,
    this.mapValueType,
  });
}
```

### 2. EnumModel

```dart
class EnumModel {
  final String name;
  final String fullName;
  final List<EnumValueModel> values;

  const EnumModel({
    required this.name,
    required this.fullName,
    required this.values,
  });
}

class EnumValueModel {
  final String name;       // Proto 原始名（如 ENUM_TYPE_UNSPECIFIED）
  final int number;        // 数值
  final String dartName;   // Dart 名（如 enumTypeUnspecified）
}
```

### 3. GrpcClient 抽象

```dart
abstract class GrpcClient {
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request,
  );

  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request,
  );
}
```

### 4. InputValidation

```dart
class InputValidationResult {
  final bool isValid;
  final List<ValidationError> errors;

  const InputValidationResult({required this.isValid, this.errors = const []});
}

class ValidationError {
  final String message;
  final String? location;

  const ValidationError(this.message, {this.location});
}

class InputValidator {
  InputValidationResult validate(CodeGeneratorRequest request) {
    // 1. 方法名唯一性检测（case-insensitive）
    // 2. 引用类型存在性检测
    // 3. 保留字冲突检测
    // 4. 空输入处理
  }
}
```

### 5. 生成器注册表

```dart
abstract class Generator {
  String get outputSuffix;
  String generate(ServiceModel service);
}

class GeneratorRegistry {
  final Map<String, Generator> _generators = {};
  
  void register(String key, Generator generator) {
    _generators[key] = generator;
  }
  
  Generator? get(String key) => _generators[key];
  
  bool isRegistered(String key) => _generators.containsKey(key);
}
```

### 6. 并行生成

可选启用模式，通过 `parallel` 标志控制：

```dart
Future<List<CodeGeneratorResponse_File>> generateAll(
  List<ServiceModel> services, {
  bool parallel = false,
}) async {
  if (parallel && services.length > 3) {
    return _generateParallel(services);
  }
  return _generateSequential(services);
}
```

### 7. 错误分层

```dart
sealed class GenerationException implements Exception {
  final String message;
  final String? location;
  
  const GenerationException(this.message, {this.location});
}

class ParseException extends GenerationException { ... }
class ValidationException extends GenerationException { ... }
class InternalException extends GenerationException { ... }
```

## 测试计划

### 单元测试

| 测试 | 文件 |
|------|------|
| FieldModel oneofName 提取 | `test/model/field_model_test.dart` |
| EnumModel 创建与命名转换 | `test/parser/enum_parsing_test.dart` |
| Map 精准检测（正例+反例） | `test/builder/http_mapper_test.dart` |
| InputValidator 验证逻辑 | `test/parser/input_validator_test.dart` |
| GrpcClient 接口使用 | `test/runtime/grpc_client_test.dart` |

### 集成测试

- 新增含 `oneof`/`map`/`enum` 的测试 fixture
- 扩展 golden 测试验证输出

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| `GrpcClient` 引入为破坏性变更 | 提供迁移辅助和缺省适配器 |
| oneof sealed class 需 Dart 3.0+ | 检查 pubspec SDK 约束 |
| 并行 Isolate 增加复杂度 | 默认关闭，仅大项目推荐启用 |
