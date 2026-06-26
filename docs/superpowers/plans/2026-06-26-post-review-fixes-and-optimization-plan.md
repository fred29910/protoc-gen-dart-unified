---
change: post-review-fixes-and-optimization
design-doc: docs/superpowers/specs/2026-06-26-post-review-fixes-and-optimization-design.md
base-ref: b65d04ebd8f14ba71fd376a51da5e0df73082f80
---

# Post-Review Fixes and Optimization — 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 基于技术审计报告修复 5 项高优先级缺陷（H1-H5）和 6 项中优先级优化（M1-M6）

**架构变更路径：** Parser 层增强 → Model 层扩展 → GrpcClient 抽象 → InputValidator → Generator 注册表 → 测试

**Tech Stack:** Dart 3.x, code_builder, protobuf, dart_style

---

## Task 1: 扩展 FieldModel 模型

**Files:**
- Modify: `lib/src/model/field_model.dart:all`
- Modify: `lib/src/model/message_model.dart:all`
- Create: `lib/src/model/enum_model.dart`

**Step 1: 创建 EnumModel/EnumValueModel**

写入 `lib/src/model/enum_model.dart`:

```dart
/// Represents a protobuf enum type definition.
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

/// Represents a single value in a protobuf enum.
class EnumValueModel {
  final String name;
  final int number;
  final String? dartName;

  const EnumValueModel({
    required this.name,
    required this.number,
    this.dartName,
  });
}
```

**Step 2: 扩展 FieldModel 添加可选字段**

修改 `lib/src/model/field_model.dart`：在现有字段后添加可空字段，保持向后兼容。

```dart
class FieldModel {
  // ... existing fields unchanged ...
  
  // New optional fields for proto3 compatibility
  final String? oneofName;
  final bool isEnum;
  final List<String>? enumValues;
  final String? mapKeyType;
  final String? mapValueType;

  const FieldModel({
    // ... existing params ...
    this.oneofName,
    this.isEnum = false,
    this.enumValues,
    this.mapKeyType,
    this.mapValueType,
  });
}
```

**Step 3: 扩展 MessageModel 添加枚举列表**

```dart
import 'enum_model.dart';

class MessageModel {
  // ... existing fields ...
  final List<EnumModel> enums;

  const MessageModel({
    // ... existing params ...
    this.enums = const [],
  });
}
```

**Verification:**
Run: `dart analyze lib/src/model/` — 应无错误

---

## Task 2: Parser 层增强 — oneof/enum/map 提取

**Files:**
- Modify: `lib/src/parser/descriptor_parser.dart`

**Step 1: 添加 map 精准检测方法**

在 `_parseMessages` 前添加辅助方法：

```dart
/// Determines if a field is a protobuf map by checking the entry message pattern.
bool _isMapField(FieldDescriptorProto f, List<DescriptorProto> messages) {
  if (f.type != FieldDescriptorProto_Type.TYPE_MESSAGE) return false;
  if (f.typeName.isEmpty) return false;
  
  final typeName = _stripTypeName(f.typeName);
  final entryMsg = messages.where((m) => m.name == typeName);
  if (entryMsg.isEmpty) return false;
  
  final fields = entryMsg.first.field;
  return fields.length == 2 &&
      fields.any((f) => f.name == 'key') &&
      fields.any((f) => f.name == 'value');
}
```

**Step 2: 在 `_parseMessages` 中提取 map 键值类型**

```dart
// Inside _parseMessages, modify the field mapping:
final fields = d.field.map((f) {
  final isMap = _isMapField(f, descriptors);
  String? mapKeyType;
  String? mapValueType;
  
  if (isMap) {
    final typeName = _stripTypeName(f.typeName);
    final entryMsg = descriptors.firstWhere((m) => m.name == typeName);
    for (final ef in entryMsg.field) {
      if (ef.name == 'key') mapKeyType = ef.type.name;
      if (ef.name == 'value') mapValueType = ef.type.name;
    }
  }
  
  return FieldModel(
    // ... existing fields unchanged ...
    isMap: isMap,
    mapKeyType: mapKeyType,
    mapValueType: mapValueType,
  );
}).toList();
```

**Step 3: 提取 oneof 元数据**

将 `DescriptorProto` 对象 `d` 传给 lambda，在字段解析中使用 oneof 信息：

```dart
// Oneof metadata
final oneofNames = d.oneofDecl.map((o) => o.name).toList();

final fields = d.field.map((f) {
  final oneofName = f.hasOneofIndex()
      ? (f.oneofIndex < oneofNames.length ? oneofNames[f.oneofIndex] : null)
      : null;
      
  return FieldModel(
    // ... existing fields ...
    oneofName: oneofName,
  );
}).toList();
```

**Step 4: 提取 enum 类型**

修改 `parse()` 方法，在解析消息后处理 enum：

```dart
// At the start of parse(), extract top-level enums
List<EnumModel> _parseEnums(FileDescriptorProto file) {
  return file.enumType.map((e) {
    return EnumModel(
      name: e.name,
      fullName: '${file.package}.${e.name}',
      values: e.value.map((v) => EnumValueModel(
        name: v.name,
        number: v.number,
      )).toList(),
    );
  }).toList();
}
```

然后关联到 MessageModel。注意：enum 可能在消息内嵌定义。
枚举类型通常出现在 `file.enumType`，但也会在 `DescriptorProto.enumType` 中（嵌套枚举）。

**Step 5: 将 enums 关联到 MessageModel**

在 `_parseMessages` 中，将文件的 enumType 解析并作为关联数据传递。

**Verification:**
Run: `dart analyze lib/src/parser/` — 应无错误

---

## Task 3: 创建 GrpcClient 抽象接口

**Files:**
- Create: `lib/src/runtime/grpc_client.dart`
- Modify: `lib/src/generators/service_generator.dart`

**Step 1: 创建 GrpcClient 接口**

```dart
import 'rpc_call_options.dart';

/// Abstract interface for gRPC clients.
///
/// Implementations wrap the generated protoc-gen-dart gRPC service clients
/// to provide type-safe access from generated Unified<Service> classes.
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

**Step 2: 修改 ServiceGenerator 使用 GrpcClient**

在 `_buildUnifiedImpl` 中，将 `_grpcClient` 类型从 `dynamic` 改为 `refer('GrpcClient')`：

```dart
// Change from:
..type = refer('dynamic')
// To:
..type = refer('GrpcClient')
```

添加 import: `Directive.import('grpc_client.dart')` (需注意路径，因为 grpc_client.dart 在 runtime 目录下)

**Step 3: 更新 gRPC 流式委托方法**

修改 `_buildGrpcServerStreamBody`：
```dart
Code _buildGrpcServerStreamBody(MethodModel method) {
  final methodName = _dartMethodName(method.name);
  return Code('''
    return _grpcClient.serverStream<${method.outputType}>(
      '${service.name}',
      '$methodName',
      request,
    );
  ''');
}
```

删除 `_buildGrpcUnaryCall` 中的 dynamic 转换，改为：
```dart
String _buildGrpcUnaryCall(MethodModel method) {
  final methodName = _dartMethodName(method.name);
  return '''_grpcClient.unaryCall<${method.outputType}>(
    '${service.name}',
    '$methodName',
    request,
  )''';
}
```

**Verification:**
Run: `dart analyze lib/src/generators/` — 确保无 dynamic 相关警告

---

## Task 4: 输入验证

**Files:**
- Create: `lib/src/parser/input_validator.dart`
- Modify: `lib/src/generator.dart`

**Step 1: 创建 InputValidator**

```dart
import '../model/service_model.dart';

class ValidationError {
  final String message;
  final String? location;
  
  const ValidationError(this.message, {this.location});
  
  @override
  String toString() => location != null
      ? '$location: $message'
      : message;
}

class InputValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  
  const InputValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

class InputValidator {
  InputValidationResult validate(List<ServiceModel> services) {
    final errors = <ValidationError>[];
    
    for (final service in services) {
      // 1. Method name uniqueness (case-insensitive)
      final methodNames = <String>{};
      for (final method in service.methods) {
        final lower = method.name.toLowerCase();
        if (methodNames.contains(lower)) {
          errors.add(ValidationError(
            'Duplicate method name "${method.name}" in service "${service.name}"',
            location: 'service:${service.name}/method:${method.name}',
          ));
        }
        methodNames.add(lower);
      }
      
      // 2. Validate input/output types exist
      for (final method in service.methods) {
        final inputExists = service.messages.any((m) => m.name == method.inputType);
        if (!inputExists) {
          errors.add(ValidationError(
            'Input type "${method.inputType}" not found for method "${method.name}"',
            location: 'service:${service.name}/method:${method.name}',
          ));
        }
        final outputExists = service.messages.any((m) => m.name == method.outputType);
        if (!outputExists) {
          errors.add(ValidationError(
            'Output type "${method.outputType}" not found for method "${method.name}"',
            location: 'service:${service.name}/method:${method.name}',
          ));
        }
      }
      
      // 3. Reserved word check for method names
      const reserved = [
        'abstract', 'as', 'assert', 'async', 'await', 'break', 'case',
        'catch', 'class', 'const', 'continue', 'covariant', 'default',
        'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
        'extension', 'external', 'factory', 'false', 'final', 'finally',
        'for', 'Function', 'get', 'hide', 'if', 'implements', 'import',
        'in', 'interface', 'is', 'late', 'library', 'mixin', 'new',
        'null', 'on', 'operator', 'part', 'required', 'rethrow', 'return',
        'set', 'show', 'static', 'super', 'switch', 'sync', 'this', 'throw',
        'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
      ];
      
      // Check Dart method names (camelCase) against reserved words
      for (final method in service.methods) {
        final dartName = method.name.isNotEmpty
            ? method.name[0].toLowerCase() + method.name.substring(1)
            : '';
        if (reserved.contains(dartName)) {
          errors.add(ValidationError(
            'Method name "${method.name}" maps to reserved Dart keyword "$dartName"',
            location: 'service:${service.name}/method:${method.name}',
          ));
        }
      }
    }
    
    return InputValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
```

**Step 2: 集成到 CodeGenerator**

在 `generator.dart` 的 `generate()` 方法中，在 parser 之后、生成之前加入验证：

```dart
import 'parser/input_validator.dart';

CodeGeneratorResponse generate(CodeGeneratorRequest request) {
  try {
    final services = _parser.parse(request.protoFile);
    
    // Input validation
    final validator = InputValidator();
    final validationResult = validator.validate(services);
    if (!validationResult.isValid) {
      final errorMsg = validationResult.errors
          .map((e) => e.toString())
          .join('\n');
      return CodeGeneratorResponse(error: 'Validation failed:\n$errorMsg');
    }
    
    // ... rest of generation logic ...
  } catch (e, st) {
    return CodeGeneratorResponse(error: 'Generation failed: $e\n$st');
  }
}
```

**Verification:**
Run: `dart analyze lib/src/` — 应无错误

---

## Task 5: 生成器注册表

**Files:**
- Modify: `lib/src/generator.dart`
- No new file needed (keep it simple - just refactor the existing code)

**Step 1: 引入 Generator 抽象接口和注册表**

在 `lib/src/generator.dart` 中添加：

```dart
abstract class Generator {
  String generate(ServiceModel service);
  String get outputSuffix;  // e.g., '.dart', '_mock.dart'
}

class GeneratorRegistry {
  final Map<String, Generator> _generators = {};
  
  void register(String key, Generator generator) {
    _generators[key] = generator;
  }
  
  Generator? operator [](String key) => _generators[key];
}
```

**Step 2: 将现有生成器适配到接口**

让 `ServiceGenerator` 扩展 `Generator` 接口... 实际上，更简单的方案是在 `CodeGenerator` 内部使用 Map 注册，不需要改变类层次结构：

```dart
class CodeGenerator {
  final DescriptorParser _parser = DescriptorParser();
  final GeneratorRegistry _registry = GeneratorRegistry();
  
  CodeGenerator() {
    _registerDefaults();
  }
  
  void _registerDefaults() {
    // Default generators registered here
  }
}
```

**Verification:**
Run: `dart analyze lib/src/generator.dart`

---

## Task 6: 测试

**Files:**
- Modify: `test/builder/http_mapper_test.dart` (extend for map detection)
- Create: `test/parser/input_validator_test.dart`

**Step 1: 创建 InputValidator 测试**

```dart
import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/parser/input_validator.dart';

void main() {
  group('InputValidator', () {
    test('detects duplicate method names (case-insensitive)', () {
      // ... test implementation
    });
    
    test('passes with unique method names', () {
      // ... test implementation
    });
    
    test('detects missing input types', () {
      // ... test implementation
    });
  });
}
```

**Step 2: 运行所有测试**

```bash
dart test
dart analyze --fatal-infos
```

---

## Task 7: 更新 Golden 测试

**Files:**
- Modify: `test/golden/golden_test.dart`
- Possibly: `test/goldens/*.golden` (regenerate)

**Step 1: 运行 golden 测试更新**

```bash
UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart
```

**Step 2: 分析变化**

```bash
git diff test/goldens/
```

确认变化的 golden 输出合理。

**Verification:**
```bash
dart test
dart analyze --fatal-infos
```
