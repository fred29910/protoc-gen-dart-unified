---
comet_change: mock-client-test-stubs
role: technical-design
canonical_spec: openspec
---

# Mock 客户端与单测桩生成 — 技术设计

## 概述

为 `protoc-gen-dart-unified` 新增 Mock 客户端和示例测试生成能力。每个 proto 服务生成三个文件：

| 文件 | 生成器 | 内容 |
|------|--------|------|
| `*_service.dart` | `ServiceGenerator`（已有） | 抽象接口 + Unified 实现 + ApiSdk |
| `*_mock.dart` | `MockServiceGenerator`（新增） | `@GenerateNiceMocks` 注解的 Mock 类 |
| `*_example_test.dart` | `ExampleTestGenerator`（新增） | 示例测试模板 |

## 架构设计

```
CodeGenerator.generate()
  ├── ServiceGenerator → *_service.dart（已有）
  ├── MockServiceGenerator → *_mock.dart（新增）
  └── ExampleTestGenerator → *_example_test.dart（新增）
```

每个生成器独立，接收 `ServiceModel`，使用 `code_builder` 构造 AST，`DartFormatter` 格式化输出。

## MockServiceGenerator 设计

### 输入
- `ServiceModel`（与 `ServiceModel` 共享）

### 输出
- `*_mock.dart` 文件

### 生成内容

```dart
// user_service_mock.dart
import 'package:mockito/annotations.dart';
import '../user.pb.dart';
import 'user_service.dart';

@GenerateNiceMocks([MockUserService])
class MockUserService implements UserService {
  @override
  Future<User> getUser(GetUserRequest request) => throw UnimplementedError();

  @override
  Future<User> createUser(CreateUserRequest request) => throw UnimplementedError();
}
```

### 关键实现点
- Mock 类名：`Mock${serviceName}`
- 实现抽象接口 `${serviceName}`
- Unary 方法返回 `Future<T>`，Server Streaming 方法返回 `Stream<T>`
- 方法体统一为 `throw UnimplementedError()`（由 mockito 覆盖）
- import `package:mockito/annotations.dart` + `../{proto}.pb.dart` + `{service}_service.dart`

## ExampleTestGenerator 设计

### 输入
- `ServiceModel`（与 `ServiceModel` 共享）

### 输出
- `*_example_test.dart` 文件

### 生成内容

```dart
// user_service_example_test.dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import '../user.pb.dart';
import 'user_service_mock.dart';
import 'user_service.dart';

void main() {
  group('UserService', () {
    late MockUserService mockUserService;

    setUp(() {
      mockUserService = MockUserService();
    });

    test('getUser returns user', () async {
      // when(mockUserService.getUser(any)).thenAnswer((_) async => User());
      // final result = await mockUserService.getUser(GetUserRequest()..id = 1);
      // expect(result, isA<User>());
    });

    test('createUser returns user', () async {
      // when(mockUserService.createUser(any)).thenAnswer((_) async => User());
      // final result = await mockUserService.createUser(CreateUserRequest()..name = 'test');
      // expect(result, isA<User>());
    });
  });
}
```

### 关键实现点
- 每个方法生成一个 `test()` 块
- Unary stub：`when(mock.method(any)).thenAnswer((_) async => T())`
- Server Streaming stub：`when(mock.method(any)).thenAnswer((_) => Stream.value(T()))`
- stub 代码以注释形式呈现，用户按需取消注释
- import `package:test/test.dart` + `package:mockito/mockito.dart` + `../{proto}.pb.dart` + `{service}_service_mock.dart` + `{service}_service.dart`

## 主生成器集成

### CodeGenerator 修改

```dart
// lib/src/generator.dart
CodeGeneratorResponse generate(CodeGeneratorRequest request) {
  final services = _parser.parse(request.protoFile);
  final files = <CodeGeneratorResponse_File>[];

  for (final service in services) {
    // 已有：service 文件
    final serviceGen = ServiceGenerator(service);
    files.add(CodeGeneratorResponse_File(
      name: '${_dartServiceName(service.name)}_service.dart',
      content: serviceGen.generate(),
    ));

    // 新增：mock 文件（默认开启，可通过参数控制）
    if (_mockEnabled) {
      final mockGen = MockServiceGenerator(service);
      files.add(CodeGeneratorResponse_File(
        name: '${_dartServiceName(service.name)}_mock.dart',
        content: mockGen.generate(),
      ));

      final testGen = ExampleTestGenerator(service);
      files.add(CodeGeneratorResponse_File(
        name: '${_dartServiceName(service.name)}_example_test.dart',
        content: testGen.generate(),
      ));
    }
  }

  return CodeGeneratorResponse(file: files);
}
```

### 插件参数

新增 `mock` 参数，默认 `true`：

```bash
protoc --dart-unified_out=. --dart-unified_opt=mock=true
```

参数解析在 `CodeGenerator` 构造时从 `CodeGeneratorRequest.parameter` 读取。

## 文件命名规则

| 服务名 | service 文件 | mock 文件 | example_test 文件 |
|--------|-------------|-----------|-------------------|
| UserService | user_service.dart | user_service_mock.dart | user_service_example_test.dart |

命名规则与 `ServiceGenerator._dartServiceName()` 保持一致：PascalCase → snake_case + 后缀。

## 测试策略

### Golden 测试
- `test/goldens/user_service_mock.dart.golden`：mock 文件期望输出
- `test/goldens/user_service_example_test.dart.golden`：example_test 文件期望输出
- 使用 `UPDATE_GOLDENS=1` 模式生成基线

### 验证
- 生成的文件通过 `dart analyze` 零错误
- 完整测试套件 `dart test` 全部通过

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| mockito API 变更 | 仅使用 `@GenerateNiceMocks` 注解，不依赖具体 API |
| Server Streaming stub 复杂性 | 使用 `Stream.value()` 提供简单 stub |
| golden 文件漂移 | 与生成器变更同步更新，CI 门禁 |
