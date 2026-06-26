# protoc-gen-dart-unified 使用说明

> 版本：0.2.0 | Dart SDK >=3.10.0 <4.0.0

---

## 目录

1. [概述](#1-概述)
2. [安装](#2-安装)
3. [基础用法](#3-基础用法)
4. [插件参数](#4-插件参数)
5. [生成产物结构](#5-生成产物结构)
6. [SDK 运行时使用](#6-sdk-运行时使用)
7. [拦截器系统](#7-拦截器系统)
8. [高级用法](#8-高级用法)
9. [验证与测试](#9-验证与测试)
10. [故障排查](#10-故障排查)
11. [项目开发指南](#11-项目开发指南)

---

## 1. 概述

`protoc-gen-dart-unified` 是一个 Dart/Flutter RPC SDK 代码生成器插件，作为 `protoc` 插件运行。它从一个 Proto 定义同时生成 **HTTP (REST/JSON via `google.api.http`)** 和 **gRPC** 双传输支持的统一客户端 SDK。

### 核心能力

| 特性 | 说明 |
| --- | --- |
| 统一接口 | 业务代码不关心底层是 HTTP 还是 gRPC，始终调用 `await sdk.service.method(request)` |
| RESTful HTTP | 绑定 `google.api.http` 注解，生成真正的 RESTful 路径映射（如 `GET /v1/users/{id}`） |
| gRPC 复用 | gRPC 侧直接复用 `protoc-gen-dart` 生成的 `*.pbgrpc.dart`，不自研 gRPC Client |
| 编译期传输选择 | 通过 Dart conditional import 在编译期决定传输层，Tree-Shaking 移除未使用的依赖 |
| 拦截器链 | Tracing → 用户拦截器 → Retry 的可组合拦截器架构 |
| 统一异常体系 | 将 `DioException` / `GrpcError` 映射成 17 种 `ApiException` 子类 |
| 跨平台 | Web（HTTP only）、Native Android/iOS/Desktop（HTTP + gRPC） |
| Mock 生成 | 可选生成 Mock 客户端和示例测试文件 |

### 架构概览

```text
.proto 文件
    │
    ▼
protoc-gen-dart-unified (protoc 插件)
    │
    ├── parser/              # 解析 FileDescriptorProto，读取 google.api.http 注解
    ├── model/               # 内部模型：ServiceModel, MethodModel, HttpRuleModel
    ├── builder/             # HTTP 映射逻辑：路径解析、Body 映射、Query 展平
    └── generators/
        ├── service_generator.dart        # 主 service 代码生成
        ├── runtime_inline_generator.dart # 自包含运行时生成（unified_runtime.dart）
        ├── mock_service_generator.dart   # Mock 客户端生成
        └── example_test_generator.dart   # 测试脚手架生成
    │
    ▼
Generated SDK (unified_runtime.dart + 每个 service 的 .dart 文件)
    │
    ▼
用户代码: await sdk.userService.getUser(GetUserRequest(id: 1))
```

---

## 2. 安装

### 2.1 前置条件

- **Dart SDK** >= 3.10.0
- **protoc** (Protocol Buffers 编译器) — 推荐 v25+
- **protoc-gen-dart** (官方 Dart gRPC 代码生成器) — 可选，仅 gRPC 场景需要

```bash
# 检查 Dart SDK 版本
dart --version

# 检查 protoc 版本
protoc --version
```

### 2.2 方法一：全局安装 (dart pub global activate)

```bash
# 从本地源码安装
dart pub global activate --source path /path/to/protoc-gen-dart-unified

# 验证安装
protoc-gen-dart-unified  # 无参数时应运行并退出（非交互式 protoc 插件）
```

### 2.3 方法二：编译为单文件二进制（推荐用于 CI）

```bash
# 编译可执行文件
dart compile exe bin/protoc_gen_dart_unified.dart -o bin/protoc-gen-dart-unified

# 将其放置在 PATH 中
export PATH="$PATH:$(pwd)/bin"

# 或者复制到系统路径
cp bin/protoc-gen-dart-unified /usr/local/bin/
```

### 2.4 方法三：从发布版本安装（当发布到 pub.dev 后）

```bash
dart pub global activate protoc_gen_dart_unified
```

### 2.5 验证安装

```bash
# 确认插件可以在 PATH 中找到
which protoc-gen-dart-unified

# 确认 protoc 可以识别该插件
protoc --help | grep dart-unified
```

---

## 3. 基础用法

### 3.1 编写 Proto 文件

假设你有一个 `user.proto`：

```protobuf
syntax = "proto3";
package user.v1;

import "google/api/annotations.proto";

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

> **注意：** `google/api/annotations.proto` 需要可被 proto 编译器解析。如果你的 `protoc` 环境中没有这个文件，请参考 [附录：获取 google.api.http 依赖](#附录获取-googleapihttp-依赖)。

### 3.2 生成代码

```bash
protoc \
  --dart-unified_out=. \
  user.proto
```

**生成的文件：**

| 文件 | 说明 |
| --- | --- |
| `unified_runtime.dart` | 自包含运行时（Transport、拦截器、SSE、Auth、Retry），仅依赖 `dio` |
| `user_service.dart` | 主文件：抽象接口 + Unified 实现 + ApiSdk 入口 |
| `user_service_mock.dart` | Mock 客户端（基于 Mockito，无需 build_runner） |
| `user_service_example_test.dart` | 示例测试文件（基于 mockito） |

`unified_runtime.dart` 由插件自动生成，**无需额外运行时包依赖**（详见第 3.3 节）。

输出目录下还需有 `protoc-gen-dart` 生成的 `user.pb.dart`（消息模型）供导入：

```bash
# 同时生成消息模型
protoc \
  --dart_out=. \
  --dart-unified_out=. \
  user.proto
```

如果不需要 Mock 和测试文件：

```bash
protoc \
  --dart-unified_out=. \
  --dart-unified_opt=mock=false \
  user.proto
```

### 3.3 在 Dart/Flutter 项目中使用生成的 SDK

**第 1 步：添加依赖**

生成的 SDK 代码包含自运行时（`unified_runtime.dart`），因此**不需要**将 `protoc_gen_dart_unified` 作为运行时依赖。只需添加 protobuf 和传输层依赖：

```yaml
dependencies:
  protobuf: ^6.0.0
  dio: ^5.9.0          # HTTP 传输（必须）
  grpc: ^5.1.0          # 仅 gRPC 传输需要
```

生成的代码通过 `unified_runtime.dart` 本地导入使用，无需包引用。

**第 2 步：使用 SDK**

生成的 `unified_runtime.dart` 位于输出目录中，与生成的 service 文件同级：

```dart
import 'generated/user_service.dart';

void main() async {
  // 创建 SDK 实例
  final sdk = ApiSdk(
    options: ClientOptions(
      endpoint: 'https://api.example.com',
      protocol: Protocol.auto,       // Web→HTTP, Native→gRPC（优先）
      timeout: const Duration(seconds: 10),
      tracingEnabled: true,          // 默认启用 traceparent 注入
      autoRetryEnabled: true,        // 默认启用自动重试
    ),
  );

  // 调用 API（业务层无感传输协议）
  final user = await sdk.userService.getUser(
    GetUserRequest(id: 1),
  );

  print('User: ${user.name} (${user.email})');
}
```

**第 3 步：使用 gRPC 传输（Native）**

当需要 gRPC 传输时，通过 `extraInterceptors`（而非 `grpcClient`，详见下节）和 `Protocol.grpc` 配置：

```dart
import 'package:grpc/grpc.dart';
import 'generated/user.pbgrpc.dart' as grpc;
import 'generated/user_service.dart';

final channel = ClientChannel(
  'api.example.com',
  port: 443,
  transportSecurity: const ChannelCredentials.secure(),
);

final sdk = ApiSdk(
  options: ClientOptions(
    endpoint: 'https://api.example.com',
    protocol: Protocol.grpc,
  ),
  extraInterceptors: const [],
);
```

> **注意：** `ApiSdk` 使用 `extraInterceptors` 参数传递额外拦截器（默认空列表）。当前版本 `grpcClient` 仅在 service 无 `google.api.http` 注解时作为构造参数传入。

---

## 4. 插件参数

通过 `--dart-unified_opt` 传递，多个参数用逗号分隔：

```bash
--dart-unified_opt=key1=value1,key2=value2
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `mock` | `true` | 是否生成 `_mock.dart` 和 `_example_test.dart`。设为 `false` 仅生成主文件 |

**示例：**

```bash
# 仅生成主文件，不含 mock 和测试
protoc --dart-unified_out=. --dart-unified_opt=mock=false user.proto
```

> **注意：** 当前仅支持 `mock` 参数。运行时行为（如 tracing、retry）通过 `ClientOptions` 配置。

---

## 5. 生成产物结构

### 5.1 主文件（`user_service.dart`）

对于一个带 `google.api.http` 注解的 `UserService`，生成三个部分：

#### 5.1.1 抽象接口

```dart
abstract class UserService {
  Future<User> getUser(GetUserRequest request);
  Future<User> createUser(CreateUserRequest request);
}
```

- 一方法对应 proto 中的一个 RPC
- Unary 返回 `Future<T>`，Server Streaming 返回 `Stream<T>`

#### 5.1.2 Unified 实现

```dart
class UnifiedUserService implements UserService {
  UnifiedUserService(this._transport, this._interceptors);

  final Transport _transport;
  final List<RpcInterceptor> _interceptors;

  @override
  Future<User> getUser(GetUserRequest request) async {
    // 构造 InterceptorContext，包含 HTTP 映射信息
    final context = InterceptorContext(
      serviceName: 'UserService',
      methodName: 'getUser',
      request: request,
      options: RpcCallOptions(
        httpMethod: 'get',
        httpPath: '/v1/users/${request.id}',
      ),
    );

    // 拦截器链（若为空则直接调用）
    if (_interceptors.isEmpty) {
      return await _transport.unaryCall<User>(...);
    }
    // ... 遍历拦截器链
  }
}
```

关键逻辑：

- **HTTP 路径自动插值**：`{id}` → `${request.id}`
- **Body 自动映射**：`body: "*"` → `request.toProto3Json()`
- **Query 自动展平**：未绑定到路径且不在 body 的字段 → URL query 参数
- **拦截器链构建**：支持 Tracing → 用户拦截器 → Retry

#### 5.1.3 ApiSdk 入口

```dart
class ApiSdk {
  ApiSdk({
    required ClientOptions options,
    List<RpcInterceptor> extraInterceptors = const [],
  }) {
    final _chain = options.buildInterceptorChain() + extraInterceptors;
    userService = UnifiedUserService(
      createTransport(options.endpoint)!,
      _chain,
    );
  }

  late UserService userService;
}
```

- 每个 service 作为一个 `late` 公开字段
- 拦截器链在构造函数中通过 `buildInterceptorChain()` + `extraInterceptors` 合并构建
- Transport 通过 `createTransport()` 工厂创建（编译期决定 Web/Native）

### 5.2 Mock 文件（`user_service_mock.dart`）

```dart
// ignore_for_file: type=lint
import 'package:mockito/mockito.dart';
import 'user.pb.dart';
import 'user_service.dart';

class MockUserService extends Mock implements UserService {}
```

- 直接继承 `Mock` 并 `implements` 抽象接口，无需注解或 `build_runner`
- 配合 `mockito` 使用：`when(mock.getUser(any)).thenAnswer(...)`

### 5.3 示例测试文件（`user_service_example_test.dart`）

```dart
// ignore_for_file: type=lint
import 'unified_runtime.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'user.pb.dart';
import 'user_service_mock.dart';
import 'user_service.dart';

void main() {
  group('UserService', () {
    late MockUserService userService;

    setUp(() {
      userService = MockUserService();
    });

    test('getUser returns User', () async {
      // when(userService.getUser(any)).thenAnswer((_) async => User());
      // final result = await userService.getUser(request);
      // expect(result, isA<User>());
    });
  });
}
```

- 使用 Mockito 框架，无需 `build_runner`

---

## 6. SDK 运行时使用

### 6.1 ClientOptions 配置

`ClientOptions` 定义在生成的 `unified_runtime.dart` 中，通过 `ApiSdk` 传入：

```dart
final sdk = ApiSdk(
  options: ClientOptions(
    endpoint: 'https://api.example.com',
    protocol: Protocol.auto,   // auto | http | grpc
    timeout: const Duration(seconds: 30),
    interceptors: [
      // 自定义拦截器
    ],
    retryPolicy: RetryPolicy(
      maxAttempts: 5,
      initialDelay: Duration(milliseconds: 100),
    ),
    tracingEnabled: true,    // 注入 W3C traceparent header
    autoRetryEnabled: true,  // 自动重试（需要设置 retryPolicy）
  ),
);
```

#### Protocol 选择逻辑

| 运行环境 | Protocol 配置 | 实际选择 |
| --- | --- | --- |
| Web | `auto` / `http` / `grpc` | **HTTP**（Web 不支持 gRPC） |
| Native | `auto` | **gRPC**（优先，须提供 grpcClient） |
| Native | `http` | HTTP |
| Native | `grpc` | gRPC（须提供 grpcClient） |

#### 拦截器链构建顺序

```
TracingInterceptor (若 enabled)
    → 用户自定义 interceptors (按添加顺序)
    → RetryInterceptor (若 enabled 且设置了 retryPolicy)
```

### 6.2 传输层选择（编译期）

本项目使用 Dart **conditional imports** 实现编译期传输选择，而非运行时 `kIsWeb` 判断。该逻辑内置于 `unified_runtime.dart` 中：

```dart
// 在 unified_runtime.dart 内部
const bool _kIsWeb = bool.fromEnvironment(
  'dart.library.js_interop',
  defaultValue: false,
);
```

- **Web 编译**：`HttpTransport` 使用 Dio 进行 HTTP 调用（SSE 不可用，抛出 `UnimplementedError`）
- **Native 编译**：`HttpTransport` 支持 HTTP unary + SSE 流式传输；gRPC 通过 `*pbgrpc.dart` 支持

> 不再需要 `transport_factory.dart` 的 conditional import——所有逻辑已内联到 `unified_runtime.dart` 中。

### 6.3 RetryPolicy 配置

```dart
// 默认策略：最多 3 次重试，200ms 初始延迟，2x 退避，25% 抖动
final retryPolicy = RetryPolicy(
  maxAttempts: 5,
  initialDelay: Duration(milliseconds: 100),
  maxDelay: Duration(seconds: 30),
  backoffMultiplier: 2.0,
  jitterFactor: 0.25,
  retryIf: (error) {
    // 自定义重试条件
    return error is UnavailableException || error is RpcTimeoutException;
  },
);
```

默认重试条件（`retryIf` 为 null 时）：

| 条件 | gRPC Code | 说明 |
| --- | --- | --- |
| `UNAVAILABLE` (14) | 503 | 服务不可用 |
| `RESOURCE_EXHAUSTED` (8) | 429 | 限流 |
| `DEADLINE_EXCEEDED` (4) | 504 | 超时 |
| 网络层错误 | 无 | 所有无 code 属性的异常均重试 |

### 6.4 统一异常体系

所有传输层异常统一映射为 `ApiException` 子类：

```dart
abstract class ApiException implements Exception {
  final String message;
  final int? code;  // 对齐 google.rpc.Code
}
```

| 业务场景 | HTTP 状态 | 异常类 |
| --- | --- | --- |
| 参数验证错误 | 400 | `InvalidArgumentException` |
| 未身份验证 | 401 | `UnauthenticatedException` |
| 权限不足 | 403 | `PermissionDeniedException` |
| 资源未找到 | 404 | `NotFoundException` |
| 资源冲突 | 409 | `AlreadyExistsException` |
| 频率超限 | 429 | `ResourceExhaustedException` |
| 前提条件不满足 | 400（映射自 9） | `FailedPreconditionException` |
| 操作中止 | 409（映射自 10） | `AbortedException` |
| 服务端内部错误 | 500 | `InternalServerException` |
| 服务不可用 | 503 | `UnavailableException` |
| 超时 | 504 | `RpcTimeoutException` |
| 已取消 | 500（映射自 1） | `CancelledException` |
| 未实现 | 501 | `UnimplementedException` |
| 数据损坏 | 500（映射自 15） | `DataLossException` |
| 未知错误 | 500（映射自 2） | `UnknownException` |

```dart
try {
  final user = await sdk.userService.getUser(request);
} on NotFoundException catch (e) {
  // 404 / NOT_FOUND
  print('User not found: ${e.message}');
} on UnauthenticatedException catch (e) {
  // 401 / UNAUTHENTICATED
  // 重定向到登录页
} on RpcTimeoutException catch (e) {
  // 504 / DEADLINE_EXCEEDED
  // 重试
} on ApiException catch (e) {
  // 所有 ApiException 的兜底
  print('RPC error (${e.code}): ${e.message}');
}
```

### 6.5 取消操作

```dart
// unified_runtime.dart 中已包含 RpcCancelToken
final cancelToken = RpcCancelToken();

// 启动异步调用
final future = sdk.userService.getUser(GetUserRequest(id: 1));

// 稍后取消
cancelToken.cancel('User navigated away');
```

---

## 7. 拦截器系统

### 7.1 内置拦截器

| 拦截器 | 说明 |
| --- | --- |
| `TracingInterceptor` | 注入 W3C `traceparent` header/metadata（默认启用） |
| `RetryInterceptor` | 指数退避 + 抖动自动重试（默认配置 `retryPolicy` 后启用） |
| `AuthInterceptor` | Bearer Token 注入 |
| `LoggingInterceptor` | 请求/响应日志 |

### 7.2 自定义拦截器

```dart
class MyAuthInterceptor extends RpcInterceptor {
  final String Function() _tokenProvider;

  MyAuthInterceptor(this._tokenProvider);

  @override
  Future<T> intercept<T>(
    InterceptorContext context,
    Future<T> Function(InterceptorContext context) proceed,
  ) async {
    // 在调用前注入 token
    final token = _tokenProvider();
    final newOptions = context.options?.copyWith(
      headers: {
        ...?context.options?.headers,
        'Authorization': 'Bearer $token',
      },
    );
    final newContext = context.copyWith(options: newOptions);
    return proceed(newContext);
  }
}
```

### 7.3 使用自定义拦截器

```dart
final sdk = ApiSdk(
  options: ClientOptions(
    endpoint: 'https://api.example.com',
    interceptors: [
      MyAuthInterceptor(() => storage.read('access_token') ?? ''),
      LoggingInterceptor(),
    ],
  ),
);
```

### 7.4 拦截器执行顺序

以 `autoRetryEnabled: true` + `tracingEnabled: true` + 2 个用户拦截器为例：

```
  TracingInterceptor  (1st - 注入 traceparent)
      ↓
  MyAuthInterceptor  (2nd - 注入 Authorization header)
      ↓
  LoggingInterceptor (3rd - 记录请求)
      ↓
  RetryInterceptor   (4th - 包裹重试逻辑)
      ↓
  Transport._rawUnaryCall (最终的 HTTP/gRPC 调用)
```

---

## 8. 高级用法

### 8.1 HTTP 映射规则详解

当 proto 方法带有 `google.api.http` 注解时，生成器按以下规则映射：

#### 路径参数绑定

```protobuf
option (google.api.http) = { get: "/v1/users/{id}" };
```
```dart
// 生成: /v1/users/${request.id}
```

#### Body 映射

```protobuf
option (google.api.http) = { post: "/v1/users", body: "*" };
```
```dart
// 生成: httpBody: request.toProto3Json()
// 整个请求消息序列化为 JSON body
```

```protobuf
option (google.api.http) = { post: "/v1/users", body: "user" };
```
```dart
// 生成: httpBody: request.user.toProto3Json()
// 仅 user 字段作为 body
```

#### Query 自动展平

请求消息中既未绑定到路径路径也不在 body 中的字段自动成为 URL Query：

```dart
// 例如 page 和 page_size 未在路径中出现，也不是 body
// 生成: httpQueryParams: { 'page': request.page, 'pageSize': request.pageSize }
```

#### response_body

```protobuf
option (google.api.http) = {
  get: "/v1/users/{id}"
  response_body: "user"
};
```

生成的代码会从响应 JSON 中提取 `response["user"]` 字段反序列化。

### 8.2 使用 buf 构建

推荐使用 [buf](https://buf.build) 管理 proto 依赖和代码生成：

**`buf.gen.yaml`：**

```yaml
version: v2
plugins:
  - local: protoc-gen-dart
    out: lib/generated
    opt: grpc
  - local: protoc-gen-dart-unified
    out: lib/generated
```

```bash
buf generate
```

### 8.3 使用 gRPC 传输（Native）

当 Protocol 为 `auto` 或 `grpc` 且 service 无 `google.api.http` 注解时，使用 gRPC 传输（通过 `extraInterceptors` 传入额外拦截器）：

```dart
import 'package:grpc/grpc.dart';
import 'generated/user.pbgrpc.dart' as grpc;

final channel = ClientChannel(
  'api.example.com',
  port: 443,
  transportSecurity: const ChannelCredentials.secure(),
);

final sdk = ApiSdk(
  options: ClientOptions(
    endpoint: 'https://api.example.com',
    protocol: Protocol.grpc,
  ),
  extraInterceptors: const [],
);
```

> 如果 service 同时包含 `google.api.http` 注解，会使用 HTTP 传输。纯 gRPC service 会自动切换到 gRPC 传输并需要 `grpcClient`。

### 8.4 Streamming 支持

| RPC 类型 | HTTP | gRPC |
| --- | --- | --- |
| Unary | ✅ 返回 `Future<T>` | ✅ 返回 `Future<T>` |
| Server Streaming | ✅ SSE（Dio `ResponseType.stream`） | ✅ 原生 `ResponseStream` |
| Client Streaming | ❌ `UnsupportedError` | ✅ 原生 `RequestStream` |
| Bidi Streaming | ❌ `UnsupportedError` | ✅ 原生 Bidi |

> HTTP Server Streaming 使用 Dio 的 `ResponseType.stream` 实现 SSE 解析，Native 平台支持，Web 平台目前抛出 `UnimplementedError`。

### 8.5 协议切换测试

```dart
// HTTP 模式
final httpSdk = ApiSdk(
  options: ClientOptions(
    endpoint: 'https://api.example.com',
    protocol: Protocol.http,
  ),
);

// gRPC 模式（Native）
final grpcSdk = ApiSdk(
  options: ClientOptions(
    endpoint: 'https://api.example.com',
    protocol: Protocol.grpc,
  ),
  grpcClient: grpc.UserServiceClient(channel),
);

// 业务代码完全相同
final user = await httpSdk.userService.getUser(GetUserRequest(id: 1));
final user2 = await grpcSdk.userService.getUser(GetUserRequest(id: 1));
```

---

## 9. 验证与测试

### 9.1 运行项目测试

```bash
# 安装依赖
dart pub get

# 运行所有测试
dart test

# 运行指定测试文件
dart test test/generator_integration_test.dart
dart test test/golden/golden_test.dart
```

### 9.2 静态分析

```bash
# 分析整个项目
dart analyze

# 分析 lib 目录
dart analyze lib/

# 分析生成代码
dart analyze lib/generated/
```

### 9.3 Golden 测试

`protoc-gen-dart-unified` 使用 golden-file 测试确保生成代码的一致性：

```bash
# 运行 golden 测试（验证输出匹配预期）
dart test test/golden/golden_test.dart

# 更新 golden 文件（当生成逻辑改变时）
UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart
```

Golden 文件位置：

```
test/goldens/
├── user_service.dart.golden
├── user_service_mock.dart.golden
└── user_service_example_test.dart.golden
```

### 9.4 端到端验证

```bash
# 1. 编译插件
dart compile exe bin/protoc_gen_dart_unified.dart -o protoc-gen-dart-unified
export PATH="$PATH:$(pwd)"

# 2. 创建一个测试项目
mkdir -p /tmp/test-sdk && cd /tmp/test-sdk

# 3. 准备 proto 文件
cat > greeter.proto << 'EOF'
syntax = "proto3";
package greet.v1;

import "google/api/annotations.proto";

service Greeter {
  rpc SayHello(HelloRequest) returns (HelloReply) {
    option (google.api.http) = { post: "/v1/greeter", body: "*" };
  }
}

message HelloRequest { string name = 1; }
message HelloReply { string greeting = 1; }
EOF

# 4. 同时生成消息模型和 SDK
protoc --dart_out=. --dart-unified_out=. greeter.proto

# 5. 验证生成的文件
ls -la greeter_service.dart
```

### 9.5 验证生成代码可编译

```dart
// verification_test.dart
import 'package:test/test.dart';

void main() {
  test('generated code compiles', () {
    // 此测试需要在包含生成代码和依赖的项目中运行
    // 确保 dart analyze 通过
  });
}
```

### 9.6 完整 CI 工作流

```yaml
# .github/workflows/ci.yml 段落示例
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: dart-lang/setup-dart@v1
      with:
        sdk: 3.10.0
    - run: dart pub get
    - run: dart analyze
    - run: dart test
    - run: dart format --output=none --set-exit-if-changed .
```

---

## 10. 故障排查

### 10.1 protoc 找不到插件

```text
protoc-gen-dart-unified: program not found or is not executable
```

**解决方法：**

```bash
# 确保插件在 PATH 中
which protoc-gen-dart-unified

# 或使用完整路径
protoc --plugin=protoc-gen-dart-unified=/path/to/protoc-gen-dart-unified ...
```

### 10.2 google.api.http 注解被忽略

如果生成的代码中没有 HTTP 映射（所有调用走 `/Service/Method` 路径），很可能是 `google/api/annotations.proto` 缺失导致 proto 编译忽略注解。

**解决方法：**

```bash
# 确保 proto 路径正确
protoc -I=/path/to/googleapis \
  --dart-unified_out=. \
  user.proto
```

**下载 googleapis：**

```bash
git clone --depth 1 https://github.com/googleapis/googleapis.git
protoc -I=googleapis -I=. \
  --dart-unified_out=. \
  user.proto
```

### 10.3 生成代码编译错误

```text
Error: Target of URI doesn't exist: '../user.pb.dart'
```

**解决方法：** 确保 `protoc-gen-dart` 先生成了 `*.pb.dart` 文件：

```bash
# 先生成消息模型，再生成 SDK
protoc --dart_out=. user.proto
protoc --dart-unified_out=. user.proto
```

### 10.4 Conditional Import 告警

在纯 Dart 项目中（无 `dart.library.js_interop` 或 `dart.library.io`）可能出现 conditional import 告警。这是预期的——项目在完整的 Dart/Flutter 环境中运行正常。

### 10.5 运行 Golden Test 失败

```text
Generated output does not match golden file.
Run with UPDATE_GOLDENS=1 to update.
```

**确认生成逻辑有意图变更后：**

```bash
UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart
```

然后将更新后的 golden 文件提交到版本控制。

---

## 11. 项目开发指南

### 11.1 快速开始

```bash
git clone <repo-url>
cd protoc-gen-dart-unified
dart pub get
dart test
```

### 11.2 常用命令

```bash
# 安装依赖
dart pub get

# 运行测试
dart test

# 运行指定测试文件
dart test test/generator_integration_test.dart

# 更新 golden 文件
UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart

# 静态分析
dart analyze --fatal-infos

# 格式化代码
dart format .

# 检查格式化（CI 模式）
dart format --output=none --set-exit-if-changed .

# 编译插件二进制
dart compile exe bin/protoc_gen_dart_unified.dart -o bin/protoc-gen-dart-unified
```

### 11.3 项目源码组织结构

```
lib/
├── protoc_gen_dart_unified.dart    # 库入口，导出 generator.dart
└── src/
    ├── generator.dart              # CodeGenerator：解析请求 → 生成响应
    ├── format_formatter.dart       # DartFormatter 封装
    ├── parser/
    │   ├── descriptor_parser.dart  # FileDescriptorProto → ServiceModel
    │   ├── extension_registry.dart # google.api.http 扩展注册
    │   └── google/api/             # 预生成的 annotations.pb 描述符
    ├── model/                      # 内部数据模型
    │   ├── service_model.dart
    │   ├── method_model.dart
    │   ├── http_rule_model.dart
    │   ├── message_model.dart
    │   └── field_model.dart
    ├── builder/                    # HTTP 映射逻辑
    │   ├── http_mapper.dart        # 路径 Body Query 映射
    │   ├── path_mapping.dart
    │   ├── body_mapping.dart
    │   └── query_field.dart
    ├── generators/                 # 代码生成器
    │   ├── service_generator.dart  # 主文件生成 (497 LOC)
    │   ├── runtime_inline_generator.dart  # 内联运行时模板 (837 LOC)
    │   ├── mock_service_generator.dart   # Mock 生成器
    │   └── example_test_generator.dart   # 测试脚手架生成器
    └── runtime/                    # SDK 运行时
        ├── transport.dart          # Transport 抽象基类
        ├── transport_factory.dart  # 条件导入工厂
        ├── transport_native.dart   # Native HTTP (Dio + SSE)
        ├── transport_web.dart      # Web HTTP (Dio)
        ├── transport_stub.dart     # 存根（fallback）
        ├── client_options.dart     # ClientOptions 配置
        ├── protocol.dart           # Protocol 枚举
        ├── rpc_interceptor.dart    # 拦截器接口
        ├── rpc_call_options.dart   # 单次调用选项
        ├── rpc_cancel_token.dart   # 取消令牌
        ├── api_exception.dart      # 统一异常体系
        ├── http_status_mapping.dart # HTTP ↔ gRPC code 映射
        ├── retry_policy.dart       # 重试策略
        ├── retry_interceptor.dart  # 重试拦截器
        ├── auth_interceptor.dart   # Auth 拦截器
        ├── tracing_interceptor.dart # 链路追踪
        ├── logging_interceptor.dart # 日志
        ├── sse_parser.dart         # SSE 解析器（Dio ResponseType.stream）
        └── with_retry.dart         # 重试工具函数

test/
├── generator_integration_test.dart  # 程序化 CodeGeneratorRequest 测试
├── golden/golden_test.dart          # Golden 快照测试
├── goldens/                         # Golden 预期输出
├── fixtures/                        # 测试用 Proto 定义
├── parser/                          # 解析器测试
├── builder/                         # HTTP 映射测试
└── runtime/                         # Runtime 测试

bin/
└── protoc_gen_dart_unified.dart     # 入口
```

### 11.4 代码生成流程

```text
protoc (CodeGeneratorRequest via stdin)
    │
    ▼
bin/protoc_gen_dart_unified.dart  (读取 stdin → Buffer)
    │
    ▼
CodeGenerator.generate( request )   (lib/src/generator.dart)
    │
    ├── DescriptorParser.parse()     (解析 descriptor → ServiceModel 列表)
    │       │
    │       └── ExtensionRegistry     (注册 google.api.http → 读取 HttpRule)
    │
    ├── RuntimeInlineGenerator.generate()  (生成 unified_runtime.dart)
    │
    ├── [foreach service]
    │   ├── ServiceGenerator.generate()  (生成主 .dart 文件)
    │   │       │
    │   │       ├── _buildAbstractInterface()  (抽象接口)
    │   │       ├── _buildUnifiedImpl()        (Unified 实现 + 拦截器链)
    │   │       └── _buildApiSdk()            (ApiSdk 入口)
    │   │
    │   ├── MockServiceGenerator.generate()   (生成 _mock.dart)
    │   │
    │   └── ExampleTestGenerator.generate()   (生成 _example_test.dart)
    │
    ▼
CodeGeneratorResponse (via stdout)
```

生成产物包含：
- `unified_runtime.dart` — 自包含运行时（每个请求仅发出一份）
- 每个 service 对应 3 个文件（主文件 + mock + example test，`mock=true` 时）

### 11.5 调试 Hints

- **打开调试日志**：暂不需要；当前没有 `--verbose` 标志
- **调试 google.api.http 解析**：检查 `DescriptorParser._extractHttpRule()` 的返回值，确保 `ExtensionRegistry` 包含了 `Annotations.http` 扩展
- **调试生成代码**：查看 `test/goldens/*.golden` 文件了解生成的预期输出
- **测试生成器**：使用 `GeneratorIntegrationTest` 以编程方式构造请求，无需 `protoc`

---

## 附录：获取 google.api.http 依赖

`google.api.http` 注解定义在 `google/api/annotations.proto` 中，属于 [googleapis](https://github.com/googleapis/googleapis) 仓库。

### 通过 git clone

```bash
git clone --depth 1 https://github.com/googleapis/googleapis.git
protoc -I=googleapis -I=. \
  --dart-unified_out=. \
  user.proto
```

### 通过 buf 依赖管理

在 `buf.yaml` 中：

```yaml
version: v2
deps:
  - buf.build/googleapis/googleapis
```

然后：

```bash
buf generate
```
