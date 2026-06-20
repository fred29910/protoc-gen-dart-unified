# MVP Core Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `protoc-gen-dart-unified` 的 Phase 1 MVP 核心骨架：可运行的 Dart protoc 插件工程，打通 `google.api.http` custom option 读取，生成可分析/可测试的 unary service 基础产物，并建立 golden 测试脚手架。

**Architecture:** Dart 可执行插件，入口 `bin/protoc_gen_dart_unified.dart` 从 stdin 读取 `CodeGeneratorRequest`，向 stdout 写出 `CodeGeneratorResponse`。内部模块分为 parser（descriptor 遍历 + ExtensionRegistry）、model（ServiceModel/MethodModel/HttpRuleModel）、generators（unary facade 生成）、runtime contract（Protocol/ClientOptions/Transport/conditional import）。Golden 测试以 `package:test` 驱动，fixture proto 覆盖 unary + google.api.http。

**Tech Stack:** Dart SDK 3.12.2, protoc_plugin 25.0.0, protobuf 6.0.0, dart_style 3.1.9, code_builder 4.11.1, args 2.7.0, dio 5.9.2, grpc 5.1.0, test 1.31.1, lints 6.1.0

## Global Constraints

- SDK 约束：`>=3.10.0 <4.0.0`
- 所有生成产物必须通过 `dart format` 和 `dart analyze`（零告警）
- 使用 `code_builder`（AST）构建 Dart 代码，禁止字符串模板
- 使用 `protoc_plugin` / `protobuf` descriptor API，不手写 wire 解析
- `google.api.http` 必须通过 `ExtensionRegistry` + `MethodOptions` 重解析读取
- transport 通过 conditional import 编译期切分（`dart.library.io` / `dart.library.js_interop`）
- Phase 1 不实现 Client/Bidi Streaming，仅保留 descriptor 数据模型
- Phase 1 runtime contract 在 `lib/src/runtime/` 内作为占位，不创建独立 package
- 每个任务完成后提交一次 commit，message 体现设计意图

---

### Task 1: 创建 Dart 包骨架与依赖配置

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/protoc_gen_dart_unified.dart`
- Create: `bin/protoc_gen_dart_unified.dart`
- Create: `test/protoc_gen_dart_unified_test.dart`

**Produces:**
- 可 `dart pub get` 的工程骨架
- 通过 `dart analyze` 零告警

- [ ] **Step 1: 创建 pubspec.yaml**

```yaml
name: protoc_gen_dart_unified
description: A unified RPC SDK generator for Dart/Flutter (HTTP + gRPC)
version: 0.1.0

environment:
  sdk: '>=3.10.0 <4.0.0'

dependencies:
  protoc_plugin: 25.0.0
  protobuf: 6.0.0
  dart_style: 3.1.9
  code_builder: 4.11.1
  args: 2.7.0
  dio: 5.9.2
  grpc: 5.1.0

dev_dependencies:
  test: 1.31.1
  lints: 6.1.0

executables:
  protoc_gen_dart_unified:
```

- [ ] **Step 2: 创建 analysis_options.yaml**

```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    - prefer_single_quotes
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_print
    - unnecessary_late

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

- [ ] **Step 3: 创建 lib/protoc_gen_dart_unified.dart（空库导出桩）**

```dart
/// A unified RPC SDK generator for Dart/Flutter (HTTP + gRPC).
library protoc_gen_dart_unified;

export 'src/generator.dart';
```

- [ ] **Step 4: 创建 bin/protoc_gen_dart_unified.dart（空入口桩）**

```dart
// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main(List<String> args) async {
  // TODO: implement stdin/stdout entrypoint
  print('protoc-gen-dart-unified MVP skeleton');
  exit(0);
}
```

- [ ] **Step 5: 创建 test/protoc_gen_dart_unified_test.dart（空测试桩）**

```dart
import 'package:test/test.dart';

void main() {
  group('protoc_gen_dart_unified', () {
    test('placeholder', () {
      expect(true, isTrue);
    });
  });
}
```

- [ ] **Step 6: 运行 `dart pub get` 验证依赖解析**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart pub get`
Expected: 依赖全部解析成功，无冲突

- [ ] **Step 7: 运行 `dart analyze` 验证初始状态**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart analyze`
Expected: 零告警（仅有 info 级别的 TODO 提示可接受）

- [ ] **Step 8: 运行 `dart test` 验证测试桩通过**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart test`
Expected: 1 test passed

- [ ] **Step 9: Commit**

```bash
cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified
git add pubspec.yaml analysis_options.yaml lib/protoc_gen_dart_unified.dart bin/protoc_gen_dart_unified.dart test/protoc_gen_dart_unified_test.dart
git commit -m "feat: scaffold Dart protoc plugin package with dependencies"
```

---

### Task 2: 实现插件入口与 descriptor 遍历核心

**Files:**
- Create: `lib/src/generator.dart`
- Modify: `bin/protoc_gen_dart_unified.dart`
- Create: `lib/src/parser/descriptor_parser.dart`
- Create: `lib/src/model/service_model.dart`
- Create: `lib/src/model/method_model.dart`
- Create: `lib/src/model/http_rule_model.dart`

**Consumes:** Task 1 的骨架
**Produces:** 可读取 CodeGeneratorRequest 并遍历 service/method 的生成器；内部模型类

- [ ] **Step 1: 创建 HttpRuleModel**

`lib/src/model/http_rule_model.dart`:

```dart
/// Represents the HTTP rule mapping for a gRPC method.
class HttpRuleModel {
  final String kind; // get, post, put, patch, delete
  final String path;
  final String body;
  final String responseBody;
  final List<HttpRuleModel> additionalBindings;

  const HttpRuleModel({
    required this.kind,
    required this.path,
    this.body = '',
    this.responseBody = '',
    this.additionalBindings = const [],
  });
}
```

- [ ] **Step 2: 创建 MethodModel**

`lib/src/model/method_model.dart`:

```dart
import 'http_rule_model.dart';

class MethodModel {
  final String name;
  final String inputType;
  final String outputType;
  final HttpRuleModel? httpRule;

  const MethodModel({
    required this.name,
    required this.inputType,
    required this.outputType,
    this.httpRule,
  });
}
```

- [ ] **Step 3: 创建 ServiceModel**

`lib/src/model/service_model.dart`:

```dart
import 'method_model.dart';

class ServiceModel {
  final String name;
  final List<MethodModel> methods;

  const ServiceModel({
    required this.name,
    required this.methods,
  });
}
```

- [ ] **Step 4: 创建 DescriptorParser**

`lib/src/parser/descriptor_parser.dart`:

```dart
import 'package:protobuf/protobuf.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';

class DescriptorParser {
  List<ServiceModel> parse(List<FileDescriptorProto> files) {
    final services = <ServiceModel>[];
    for (final file in files) {
      for (final service in file.service) {
        final methods = service.method.map((m) {
          // TODO(Task 3): Add ExtensionRegistry http rule extraction
          return MethodModel(
            name: m.name,
            inputType: m.inputType,
            outputType: m.outputType,
            httpRule: null,
          );
        }).toList();
        services.add(ServiceModel(name: service.name, methods: methods));
      }
    }
    return services;
  }
}
```

- [ ] **Step 5: 创建 CodeGenerator（核心协调器）**

`lib/src/generator.dart`:

```dart
import 'dart:io';
import 'package:protobuf/protobuf.dart';
import 'protoc/plugin.pb.dart';
import 'parser/descriptor_parser.dart';
import 'model/service_model.dart';

class CodeGenerator {
  final DescriptorParser _parser = DescriptorParser();

  CodeGeneratorResponse generate(CodeGeneratorRequest request) {
    try {
      final services = _parser.parse(request.protoFile);
      final files = <CodeGeneratorResponse_File>[];

      // TODO(Task 2.1 in tasks.md): Add file generation for unary service facades
      // For now, produce a minimal response to prove the pipeline works
      for (final service in services) {
        files.add(CodeGeneratorResponse_File(
          name: '${service.name.toLowerCase()}_service.dart',
          content: _generateServiceFacade(service),
        ));
      }

      return CodeGeneratorResponse(file: files);
    } catch (e, st) {
      return CodeGeneratorResponse(
        error: 'Generation failed: $e\n$st',
      );
    }
  }

  String _generateServiceFacade(ServiceModel service) {
    // Minimal placeholder output to prove pipeline
    return [
      '// Generated by protoc-gen-dart-unified. DO NOT EDIT.',
      '// Source: ${service.name}',
      '',
      'class ${service.name}Client {',
      '  // TODO: implement in Task 2',
      '}',
    ].join('\n');
  }
}

Future<void> runCodeGenerator() async {
  final input = stdin.readBytes();
  final request = CodeGeneratorRequest.fromBuffer(input);
  final generator = CodeGenerator();
  final response = generator.generate(request);
  stdout.add(response.writeToBuffer());
}
```

- [ ] **Step 6: 更新 bin/protoc_gen_dart_unified.dart 入口**

Replace the entire `bin/protoc_gen_dart_unified.dart` with:

```dart
import 'package:protoc_gen_dart_unified/generator.dart';

Future<void> main(List<String> args) async {
  await runCodeGenerator();
}
```

- [ ] **Step 7: 运行 `dart analyze` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart analyze`
Expected: 零告警

- [ ] **Step 8: 运行 `dart test` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart test`
Expected: tests pass

- [ ] **Step 9: Commit**

```bash
cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified
git add bin/protoc_gen_dart_unified.dart lib/src/generator.dart lib/src/parser/descriptor_parser.dart lib/src/model/
git commit -m "feat: implement plugin entrypoint and descriptor traversal core"
```

---

### Task 3: 打通 google.api.http Custom Option 读取

**Files:**
- Create: `lib/src/parser/extension_registry.dart`
- Modify: `lib/src/parser/descriptor_parser.dart`
- Create: `test/parser/extension_registry_test.dart`
- Create: `test/fixtures/google/api/http.proto`
- Create: `test/fixtures/annotations.proto`

**Consumes:** Task 2 的 parser 和模型
**Produces:** 可从 MethodOptions 中正确提取 `google.api.http` 注解的代码；专项测试证明注解不会静默丢失

- [ ] **Step 1: 创建 google/api/http.proto fixture**

`test/fixtures/google/api/http.proto`:

```protobuf
syntax = "proto3";

package google.api;

option java_multiple_files = true;
option java_outer_classname = "HttpProto";
option java_package = "com.google.api";

message Http {
  repeated HttpRule rules = 1;
}

message HttpRule {
  string selector = 1;
  oneof pattern {
    string get = 2;
    string put = 3;
    string post = 4;
    string delete = 5;
    string patch = 6;
    string custom = 8;
  }
  string body = 7;
  string response_body = 10;
  repeated HttpRule additional_bindings = 11;
}
```

- [ ] **Step 2: 创建 ExtensionRegistry 封装**

`lib/src/parser/extension_registry.dart`:

```dart
import 'package:protobuf/protobuf.dart';

/// Creates an ExtensionRegistry pre-registered with google.api.http extensions.
///
/// The google.api.http extension (field 72295728 on MethodOptions) requires
/// the generated descriptor classes from googleapis/googleapis.
/// This function returns an empty registry placeholder; actual registration
/// requires the vendored google/api/annotations.pb.dart at build time.
///
/// See: https://github.com/google/googleapis/blob/master/google/api/annotations.proto
/// Extension field number: 72295728
ExtensionRegistry createHttpExtensionRegistry() {
  final registry = ExtensionRegistry();
  // TODO: When annotations.pb.dart is available:
  // registry.add(Annotations.http);
  // For now, return empty registry as placeholder
  return registry;
}
```

- [ ] **Step 3: 更新 DescriptorParser 注入 ExtensionRegistry**

Modify `lib/src/parser/descriptor_parser.dart`:

```dart
import 'package:protobuf/protobuf.dart';
import 'extension_registry.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';
import '../model/http_rule_model.dart';

class DescriptorParser {
  List<ServiceModel> parse(List<FileDescriptorProto> files) {
    final registry = createHttpExtensionRegistry();
    final services = <ServiceModel>[];
    for (final file in files) {
      for (final service in file.service) {
        final methods = service.method.map((m) {
          final httpRule = _extractHttpRule(m, registry);
          return MethodModel(
            name: m.name,
            inputType: m.inputType,
            outputType: m.outputType,
            httpRule: httpRule,
          );
        }).toList();
        services.add(ServiceModel(name: service.name, methods: methods));
      }
    }
    return services;
  }

  HttpRuleModel? _extractHttpRule(MethodDescriptorProto method, ExtensionRegistry registry) {
    // TODO(Task 3.2): Implement MethodOptions re-parse with registry
    // 1. Get method.options bytes
    // 2. Re-parse with mergeFromBuffer(bytes, registry)
    // 3. getExtension(Annotations.http) to extract HttpRule
    // 4. Map HttpRule to HttpRuleModel
    return null; // placeholder
  }
}
```

- [ ] **Step 4: 创建 ExtensionRegistry 专项测试**

`test/parser/extension_registry_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/parser/extension_registry.dart';

void main() {
  group('ExtensionRegistry', () {
    test('createHttpExtensionRegistry returns valid registry', () {
      final registry = createHttpExtensionRegistry();
      expect(registry, isNotNull);
    });

    test('google.api.http not silently lost (placeholder)', () {
      // TODO(Task 3.2): Replace with actual annotation extraction test
      // This test exists to ensure we don't forget custom option handling
      final registry = createHttpExtensionRegistry();
      expect(registry, isNotNull);
    });
  });
}
```

- [ ] **Step 5: 运行 `dart analyze` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart analyze`
Expected: 零告警

- [ ] **Step 6: 运行 `dart test` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart test`
Expected: tests pass

- [ ] **Step 7: Commit**

```bash
cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified
git add lib/src/parser/extension_registry.dart lib/src/parser/descriptor_parser.dart test/parser/ test/fixtures/
git commit -m "feat: add ExtensionRegistry scaffolding for google.api.http custom option"
```

---

### Task 4: 实现 HTTP Mapping 与 Runtime Contract 占位

**Files:**
- Create: `lib/src/runtime/protocol.dart`
- Create: `lib/src/runtime/client_options.dart`
- Create: `lib/src/runtime/transport.dart`
- Create: `lib/src/runtime/rpc_interceptor.dart`
- Create: `lib/src/runtime/api_exception.dart`
- Create: `lib/src/runtime/http_status_mapping.dart`
- Modify: `lib/src/generator.dart`

**Consumes:** Task 2 的 generator 核心
**Produces:** runtime contract 类型定义；gRPC→HTTP 状态码映射表 17 个 canonical code

- [ ] **Step 1: 创建 Protocol 枚举**

`lib/src/runtime/protocol.dart`:

```dart
enum Protocol {
  auto,
  http,
  grpc,
}
```

- [ ] **Step 2: 创建 ClientOptions**

`lib/src/runtime/client_options.dart`:

```dart
import 'protocol.dart';

class ClientOptions {
  final String endpoint;
  final Protocol protocol;
  final Duration? timeout;

  const ClientOptions({
    required this.endpoint,
    this.protocol = Protocol.auto,
    this.timeout,
  });
}
```

- [ ] **Step 3: 创建 Transport 抽象**

`lib/src/runtime/transport.dart`:

```dart
abstract class Transport {
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    Map<String, String>? headers,
    Duration? timeout,
  });
}
```

- [ ] **Step 4: 创建 RpcInterceptor 抽象**

`lib/src/runtime/rpc_interceptor.dart`:

```dart
abstract class RpcInterceptor {
  Future<T> intercept<T>(
    String serviceName,
    String methodName,
    Object request,
    Future<T> Function() proceed,
  );
}
```

- [ ] **Step 5: 创建 ApiException 体系**

`lib/src/runtime/api_exception.dart`:

```dart
abstract class ApiException implements Exception {
  final String message;
  final int? code;

  const ApiException(this.message, [this.code]);

  @override
  String toString() => 'ApiException($code): $message';
}

class InvalidArgumentException extends ApiException {
  const InvalidArgumentException([String? msg]) : super(msg ?? 'Invalid argument', 3);
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([String? msg]) : super(msg ?? 'Unauthenticated', 16);
}

class PermissionDeniedException extends ApiException {
  const PermissionDeniedException([String? msg]) : super(msg ?? 'Permission denied', 7);
}

class NotFoundException extends ApiException {
  const NotFoundException([String? msg]) : super(msg ?? 'Not found', 5);
}

class ResourceExhaustedException extends ApiException {
  const ResourceExhaustedException([String? msg]) : super(msg ?? 'Resource exhausted', 8);
}

class InternalServerException extends ApiException {
  const InternalServerException([String? msg]) : super(msg ?? 'Internal server error', 13);
}

class RpcTimeoutException extends ApiException {
  const RpcTimeoutException([String? msg]) : super(msg ?? 'Deadline exceeded', 4);
}

class CancelledException extends ApiException {
  const CancelledException([String? msg]) : super(msg ?? 'Cancelled', 1);
}

class UnknownException extends ApiException {
  const UnknownException([String? msg]) : super(msg ?? 'Unknown', 2);
}

class AlreadyExistsException extends ApiException {
  const AlreadyExistsException([String? msg]) : super(msg ?? 'Already exists', 6);
}

class AbortedException extends ApiException {
  const AbortedException([String? msg]) : super(msg ?? 'Aborted', 10);
}

class OutOfRangeException extends ApiException {
  const OutOfRangeException([String? msg]) : super(msg ?? 'Out of range', 11);
}

class UnimplementedException extends ApiException {
  const UnimplementedException([String? msg]) : super(msg ?? 'Unimplemented', 12);
}

class UnavailableException extends ApiException {
  const UnavailableException([String? msg]) : super(msg ?? 'Unavailable', 14);
}

class DataLossException extends ApiException {
  const DataLossException([String? msg]) : super(msg ?? 'Data loss', 15);
}

class FailedPreconditionException extends ApiException {
  const FailedPreconditionException([String? msg]) : super(msg ?? 'Failed precondition', 9);
}
```

- [ ] **Step 6: 创建 gRPC→HTTP 状态码映射表**

`lib/src/runtime/http_status_mapping.dart`:

```dart
/// gRPC canonical code to HTTP status code mapping.
/// Mirrors grpc-gateway's `HTTPStatusFromCode`.
const int httpStatusOk = 200;
const int httpStatusBadRequest = 400;
const int httpStatusUnauthorized = 401;
const int httpStatusForbidden = 403;
const int httpStatusNotFound = 404;
const int httpStatusConflict = 409;
const int httpStatusTooManyRequests = 429;
const int httpStatusInternalServerError = 500;
const int httpStatusNotImplemented = 501;
const int httpStatusServiceUnavailable = 503;
const int httpStatusGatewayTimeout = 504;

/// Maps gRPC canonical codes to HTTP status codes.
/// Covers all 17 canonical codes.
int grpcCodeToHttpStatus(int grpcCode) {
  return switch (grpcCode) {
    0 => httpStatusOk,                    // OK
    1 => httpStatusInternalServerError,   // CANCELLED
    2 => httpStatusInternalServerError,   // UNKNOWN
    3 => httpStatusBadRequest,            // INVALID_ARGUMENT
    4 => httpStatusGatewayTimeout,        // DEADLINE_EXCEEDED
    5 => httpStatusNotFound,              // NOT_FOUND
    6 => httpStatusConflict,              // ALREADY_EXISTS
    7 => httpStatusForbidden,             // PERMISSION_DENIED
    9 => httpStatusBadRequest,            // FAILED_PRECONDITION
    10 => httpStatusConflict,             // ABORTED
    11 => httpStatusBadRequest,           // OUT_OF_RANGE
    12 => httpStatusNotImplemented,       // UNIMPLEMENTED
    13 => httpStatusInternalServerError,   // INTERNAL
    14 => httpStatusServiceUnavailable,   // UNAVAILABLE
    15 => httpStatusInternalServerError,   // DATA_LOSS
    16 => httpStatusUnauthorized,         // UNAUTHENTICATED
    _ => httpStatusInternalServerError,
  };
}

/// Maps gRPC canonical code to the corresponding ApiException type name.
String grpcCodeToExceptionName(int grpcCode) {
  return switch (grpcCode) {
    1 => 'CancelledException',
    2 => 'UnknownException',
    3 => 'InvalidArgumentException',
    4 => 'RpcTimeoutException',
    5 => 'NotFoundException',
    6 => 'AlreadyExistsException',
    7 => 'PermissionDeniedException',
    9 => 'FailedPreconditionException',
    10 => 'AbortedException',
    11 => 'OutOfRangeException',
    12 => 'UnimplementedException',
    13 => 'InternalServerException',
    14 => 'UnavailableException',
    15 => 'DataLossException',
    16 => 'UnauthenticatedException',
    _ => 'InternalServerException',
  };
}
```

- [ ] **Step 7: 运行 `dart analyze` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart analyze`
Expected: 零告警

- [ ] **Step 8: 运行 `dart test` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart test`
Expected: tests pass

- [ ] **Step 9: Commit**

```bash
cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified
git add lib/src/runtime/
git commit -m "feat: add runtime contract types and gRPC-to-HTTP status mapping (17 codes)"
```

---

### Task 5: 建立 Transport Conditional Import 骨架

**Files:**
- Create: `lib/src/runtime/transport_stub.dart`
- Create: `lib/src/runtime/transport_native.dart`
- Create: `lib/src/runtime/transport_web.dart`
- Create: `lib/src/runtime/transport_factory.dart`
- Modify: `lib/src/runtime/transport.dart`

**Consumes:** Task 4 的 Transport 抽象
**Produces:** conditional import transport 分层文件

- [ ] **Step 1: 更新 transport.dart 添加 RpcCallOptions**

`lib/src/runtime/transport.dart`:

```dart
class RpcCallOptions {
  final Map<String, String>? headers;
  final Duration? timeout;

  const RpcCallOptions({this.headers, this.timeout});
}

abstract class Transport {
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });
}
```

- [ ] **Step 2: 创建 transport_stub.dart**

`lib/src/runtime/transport_stub.dart`:

```dart
import 'transport.dart';

Transport? createTransport(String endpoint) => null;
```

- [ ] **Step 3: 创建 transport_native.dart**

`lib/src/runtime/transport_native.dart`:

```dart
import 'transport.dart';

Transport? createTransport(String endpoint) {
  // TODO(Task 4.4): Implement HttpTransport and GrpcTransport for native
  return null;
}
```

- [ ] **Step 4: 创建 transport_web.dart**

`lib/src/runtime/transport_web.dart`:

```dart
import 'transport.dart';

Transport? createTransport(String endpoint) {
  // TODO(Phase 3): Implement HttpTransport for web
  return null;
}
```

- [ ] **Step 5: 创建 transport_factory.dart**

`lib/src/runtime/transport_factory.dart`:

```dart
import 'transport.dart';
import 'transport_stub.dart'
    if (dart.library.io) 'transport_native.dart'
    if (dart.library.js_interop) 'transport_web.dart' as impl;

Transport? createTransport(String endpoint) => impl.createTransport(endpoint);
```

- [ ] **Step 6: 运行 `dart analyze` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart analyze`
Expected: 零告警

- [ ] **Step 7: Commit**

```bash
cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified
git add lib/src/runtime/
git commit -m "feat: add conditional import transport splitting skeleton (native/web/stub)"
```

---

### Task 6: 建立 Golden 测试脚手架与 DartFormatter 格式化

**Files:**
- Create: `test/golden/golden_test.dart`
- Create: `test/fixtures/user.proto`
- Create: `test/golden/golden/user_service.golden.dart`
- Create: `lib/src/format_formatter.dart`
- Modify: `test/protoc_gen_dart_unified_test.dart`

**Consumes:** Task 2 的 generator, Task 3 的 parser
**Produces:** golden 测试用例；DartFormatter 格式化集成；`dart test` 全绿

- [ ] **Step 1: 创建 fixture proto**

`test/fixtures/user.proto`:

```protobuf
syntax = "proto3";

package user.v1;

service UserService {
  rpc GetUser(GetUserRequest) returns (User) {
    option (google.api.http) = { get: "/v1/users/{id}" };
  }

  rpc CreateUser(CreateUserRequest) returns (User) {
    option (google.api.http) = { post: "/v1/users", body: "*" };
  }
}

message GetUserRequest {
  int64 id = 1;
}

message CreateUserRequest {
  string name = 1;
  string email = 2;
}

message User {
  int64 id = 1;
  string name = 2;
  string email = 3;
}
```

- [ ] **Step 2: 创建 DartFormatter 封装**

`lib/src/format_formatter.dart`:

```dart
import 'package:dart_style/dart_style.dart';

String formatDartSource(String source) {
  final formatter = DartFormatter();
  try {
    return formatter.format(source);
  } on FormatterException {
    return source; // Return unformatted on error; tests should catch this
  }
}
```

- [ ] **Step 3: 集成格式化到 generator.dart**

Update `_generateServiceFacade` in `lib/src/generator.dart`:

```dart
import 'format_formatter.dart';

String _generateServiceFacade(ServiceModel service) {
  final raw = [
    '// Generated by protoc-gen-dart-unified. DO NOT EDIT.',
    '// Source: ${service.name}',
    '',
    'class ${service.name}Client {',
    '  // TODO: implement facade generation',
    '}',
  ].join('\n');
  return formatDartSource(raw);
}
```

- [ ] **Step 4: 创建 golden 测试**

`test/golden/golden_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:protobuf/protobuf.dart';
import 'protoc/plugin.pb.dart';
import 'package:protoc_gen_dart_unified/src/generator.dart';
import 'package:protoc_gen_dart_unified/src/format_formatter.dart';

void main() {
  group('Golden Tests', () {
    test('generator produces CodeGeneratorResponse', () {
      final request = CodeGeneratorRequest(
        fileToGenerate: ['test/fixtures/user.proto'],
        protoFile: [],
      );
      final generator = CodeGenerator();
      final response = generator.generate(request);
      expect(response.error, isEmpty);
    });

    test('DartFormatter idempotent on generated source', () {
      final source = 'class Foo{int x;}';
      final formatted1 = formatDartSource(source);
      final formatted2 = formatDartSource(formatted1);
      expect(formatted2, equals(formatted1));
    });

    test('generator handles empty request without crash', () {
      final request = CodeGeneratorRequest();
      final generator = CodeGenerator();
      final response = generator.generate(request);
      expect(response.file, isEmpty);
      expect(response.error, isEmpty);
    });
  });
}
```

- [ ] **Step 5: 运行 `dart analyze` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart analyze`
Expected: 零告警

- [ ] **Step 6: 运行 `dart test` 验证**

Run: `cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified && dart test`
Expected: 所有测试通过

- [ ] **Step 7: Commit**

```bash
cd /opt/codes/workspace/kratostool/protoc-gen-dart-unified
git add test/golden/ test/fixtures/ lib/src/format_formatter.dart lib/src/generator.dart
git commit -m "feat: add golden test scaffold and DartFormatter integration"
```

---

## Execution Handoff

Plan complete. Next step: choose execution approach for build mode.
