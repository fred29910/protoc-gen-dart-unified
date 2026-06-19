# protoc-gen-dart-unified

> 面向 Flutter 全平台（Web / Android / iOS / Desktop）的统一 RPC SDK 生成器

## 项目目标

`protoc-gen-dart-unified` 是一个基于 Protocol Buffers 的 Dart/Flutter 客户端代码生成器。

设计目标：

* 支持 HTTP(JSON) 与 gRPC(Protobuf)
* Flutter Web 自动使用 HTTP
* Flutter Native 自动支持 gRPC
* 支持运行时切换协议
* 调用端完全无感底层协议
* 单文件生成
* 支持 grpc-gateway / google.api.http 注解
* 支持拦截器
* 支持 Streaming
* 支持 OpenTelemetry
* 支持未来 ConnectRPC 扩展

---

# 设计原则

## 统一接口

业务代码永远不关心：

* HTTP
* gRPC
* grpc-web
* SSE

调用方式始终一致：

```dart
final userService = sdk.userService;

final user = await userService.getUser(
  GetUserRequest(id: 1),
);
```

---

## 环境自动识别

### Browser

自动：

```text
HTTP(JSON)
```

原因：

```text
grpc-web限制较多
代理复杂
CORS复杂
部署成本高
```

因此：

```dart
if (kIsWeb) {
  protocol = Protocol.http;
}
```

---

### Native

支持：

```text
Android
iOS
macOS
Windows
Linux
```

允许：

```dart
Protocol.grpc
Protocol.http
```

动态切换。

---

## 协议无感知

业务代码：

```dart
await userService.getUser(...)
```

底层可能是：

```text
HTTP
gRPC
```

自动路由。

---

# 技术选型

## Message

官方 protobuf 实现

```yaml
protobuf: ^4.x
```

生成：

```dart
user.pb.dart
```

来源：

```bash
protoc-gen-dart
```

---

## HTTP Client

推荐：

```yaml
dio: ^5.x
```

原因：

* Flutter支持最好
* Web支持最好
* Interceptor成熟
* Timeout支持
* Upload/Download支持
* 社区活跃

统一HTTP实现：

```dart
class HttpTransport
```

---

## gRPC Client

使用：

```yaml
grpc: ^4.x
```

官方实现：

```dart
ClientChannel
```

统一：

```dart
class GrpcTransport
```

---

## Runtime Detection

环境判定应优先支持纯 Dart 环境（如 CLI、命令行工具、服务端），避免强依赖 Flutter 框架。

**判断方式**：

对于纯 Dart 环境（兼容 CLI 与 Native）：

```dart
const bool kIsWeb = identical(0, 0.0);
```

对于 Flutter 工程：

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
```

---

## Serialization

优先：

```text
protobuf binary
```

兼容：

```text
json
```

处理 JSON 兼容时，应利用官方 `protobuf` 库内置的 `toProto3Json()` 和 `mergeFromProto3Json()` 方法进行序列化与反序列化，确保对 Well-Known Types（如 Timestamp、Any 等）以及字段命名（json_name）的严格契约转换。

生成：

```dart
Message.toProto3Json()
Message.mergeFromProto3Json()
Message.writeToBuffer()
Message.fromBuffer()
```

---

## Logging

推荐：

```yaml
logger: ^2.x
```

统一：

```dart
LoggingInterceptor
```

---

## OpenTelemetry

推荐：

```yaml
opentelemetry: ^0.18+
```

支持：

```text
Jaeger
Tempo
Zipkin
OTLP
```

---

# 插件架构

```text
proto
   │
   ▼

protoc-gen-dart-unified

   │
   ▼

Generated SDK
```

---

# Generator Architecture

```text
generator/

├── parser/
│
├── model/
│
├── templates/
│
├── generators/
│
└── runtime/
```

---

## parser

负责解析：

```proto
service UserService

rpc GetUser
```

以及：

```proto
option (google.api.http)
```

---

## model

统一内部模型：

```dart
ServiceModel
MethodModel
MessageModel
HttpRuleModel
```

---

## generators

```text
GrpcGenerator
HttpGenerator
FacadeGenerator
SdkGenerator
```

---

## runtime

生成SDK依赖的运行时。

例如：

```dart
Protocol
Transport
ClientOptions
Interceptor
```

---

# 支持的 Proto 特性

## Unary

```proto
rpc GetUser(GetUserRequest)
returns(User);
```

生成：

```dart
Future<User> getUser(...)
```

---

## Server Streaming

```proto
rpc WatchUser(...)
returns(stream User);
```

生成：

```dart
Stream<User>
```

---

## Client Streaming

```proto
rpc Upload(...)
returns(Response);
```

生成：

```dart
Future<Response>
```

---

## Bidirectional Streaming

```proto
rpc Chat(stream Message)
returns(stream Message);
```

生成：

```dart
Stream<Message>
```

---

# HTTP Mapping

支持：

```proto
option (google.api.http) = {
  get: "/v1/users/{id}"
};
```

生成：

```dart
dio.get("/v1/users/$id");
```

---

支持：

```proto
get
post
put
patch
delete
```

映射：

| Proto  | HTTP   |
| ------ | ------ |
| get    | GET    |
| post   | POST   |
| put    | PUT    |
| patch  | PATCH  |
| delete | DELETE |

注意：除了被映射为路径参数的字段外，Request Message 中的其余字段会被自动展平（Flatten）为 URL Query Parameters（针对 GET/DELETE 请求）或序列化为 Request Body（针对 POST/PUT/PATCH 请求）。在处理复杂嵌套 Message 转换为 Query 参数时，需严格遵循 gRPC-Gateway 的规范。

---

# SDK Runtime

为了避免在生成多个服务时产生类型冲突和代码冗余，建议将底层的 `Protocol`、`Transport`、`Interceptor` 接口以及统一的 `ApiException` 错误基类等，抽离为一个极轻量的独立 Dart package（如 `protoc_gen_dart_unified_runtime`）。所有生成的代理代码统一依赖该运行时包。

## Protocol

```dart
enum Protocol {
  auto,
  http,
  grpc,
}
```

---

## ClientOptions

```dart
class ClientOptions {
  final String endpoint;
  final Protocol protocol;
}
```

---

## SDK

```dart
final sdk = ApiSdk(
  ClientOptions(
    endpoint: "https://api.example.com",
    protocol: Protocol.auto,
  ),
);
```

---

# Transport抽象

## 接口

```dart
abstract class Transport {
  Future<T> unaryCall<T>(
    MethodDescriptor descriptor,
    Object request,
  );
}
```

---

## HTTP实现

```dart
class HttpTransport
implements Transport
```

内部：

```text
dio
json
```

---

## gRPC实现

```dart
class GrpcTransport
implements Transport
```

内部：

```text
grpc package
protobuf
```

---

# Unified Service

生成：

```dart
abstract class UserService {
  Future<User> getUser(
    GetUserRequest request,
  );
}
```

实现：

```dart
class UnifiedUserService
implements UserService
```

自动路由：

```text
Protocol.http
Protocol.grpc
```

---

# 单文件生成模式

目标：

```text
user_service.dart
```

包含：

- **Facade & Unified Interface** (客户端统一服务接口与包装实现)
- **HttpTransport & GrpcTransport** (底层的双协议客户端网络通道实现)
- **SDK 入口类** (如 `ApiSdk`)
- **Descriptor** (服务与方法描述符)

注意：
为了避免与官方 `protoc-gen-dart` 重复实现庞大的 Message 序列化和未知字段处理逻辑，单文件生成的 `user_service.dart` 应通过 **import 导入** 官方生成的消息模型文件（如 `user.pb.dart`），而非在单文件中重新内联 Message 的定义。

**依赖控制与 Tree Shaking**：
虽然 Dart 有良好的 Tree Shaking 机制，但依然要求生成的代码在包引入时保持克制。例如当插件参数 `transport=http` 时，生成的代码**绝不能**包含任何 `grpc` package 的 import 语句，以此消除在纯 Web 项目中的包体积虚高和兼容性隐患。

避免：

```text
20+
客户端适配与通信管道碎片文件
```

---

# Interceptor系统

统一接口：

```dart
abstract class Interceptor
```

支持：

```text
Auth
Retry
Logging
Metrics
Tracing
Cache
```

---

示例：

```dart
sdk.addInterceptor(
  AuthInterceptor(tokenProvider),
);
```

---

# Retry机制

支持：

```dart
RetryPolicy(
  maxAttempts: 3,
)
```

支持：

```text
Exponential Backoff
Jitter
```

---

# Error Mapping

为了在调用端提供无感知的异常处理，Transport 层需要捕获底层异构网络库的异常（如 DioException、GrpcError），并将其映射到统一的 `ApiException` 继承体系中。

统一异常基类：

```dart
abstract class ApiException implements Exception {
  final String message;
  final int? code; // 统一的错误码
  ApiException(this.message, [this.code]);
}
```

标准错误映射表：

| 业务场景 | gRPC 状态码 | HTTP 状态码 | 统一异常类型 |
| :--- | :--- | :--- | :--- |
| 参数验证错误 | `INVALID_ARGUMENT (3)` | `400 Bad Request` | `InvalidArgumentException` |
| 未身份验证 | `UNAUTHENTICATED (16)` | `401 Unauthorized` | `UnauthenticatedException` |
| 权限不足 | `PERMISSION_DENIED (7)` | `403 Forbidden` | `PermissionDeniedException` |
| 资源未找到 | `NOT_FOUND (5)` | `404 Not Found` | `NotFoundException` |
| 频率超限 | `RESOURCE_EXHAUSTED (8)`| `429 Too Many Requests` | `ResourceExhaustedException` |
| 服务端内部错误 | `INTERNAL (13)` | `500 Internal Error` | `InternalServerException` |
| 网络连接超时 | `DEADLINE_EXCEEDED (4)` | `504 Gateway Timeout` | `TimeoutException` |

---

# OpenTelemetry

自动生成：

```dart
Span
TraceContext
```

支持：

```text
grpc metadata
http header
```

自动注入。

---

# Streaming设计

对于流式 RPC 请求，统一暴露 `Stream<T>` 给业务层。但在底层不同的 Transport 协议中，其支持度有所不同：

- **Server Streaming** (服务端单向流):
  - gRPC: 使用 `ResponseStream` 原生接收。
  - HTTP/JSON: 采用 **SSE (Server-Sent Events)** 协议实现，通过分块读取响应体转换成 Stream。
- **Client/Bidirectional Streaming** (客户端流 / 双向流):
  - gRPC: 原生支持 `RequestStream` 和 `BidirectionalStream`。
  - HTTP/JSON: 在标准 HTTP/1.1 (JSON) 降级方案中，将不支持流式写入（调用时抛出 `UnsupportedError`），未来在 Phase 3 中通过 **WebSocket** 或 **ConnectRPC (HTTP/2)** 实现流式交互。

---

# 生成示例

Proto：

```proto
service UserService {

  rpc GetUser(GetUserRequest)
  returns(User) {

    option (google.api.http) = {
      get: "/v1/users/{id}"
    };
  }
}
```

生成：

```dart
final sdk = ApiSdk(options);

final user =
    await sdk.userService.getUser(
      GetUserRequest(id: 1),
    );
```

业务层无需关心：

```text
HTTP
gRPC
Web
Android
iOS
Desktop
```

---

# 插件参数

```bash
protoc \
  --dart-unified_out=. \
  --dart-unified_opt=
      single_file=true,
      protocol=auto,
      transport=http,grpc
```

---

支持参数

| 参数          | 默认        | 说明            |
| ----------- | --------- | ------------- |
| single_file | true      | 单文件生成 (如果 Proto 过于庞大，可设为 false 降级为多文件) |
| protocol    | auto      | 默认协议          |
| transport   | http,grpc | 支持协议          |
| use_dio     | true      | Dio客户端        |
| tracing     | true      | OpenTelemetry |
| interceptor | true      | 拦截器           |
| retry       | true      | 自动重试          |

---

# 未来规划

## Phase 1: MVP 核心骨架

支持：

```text
- Unary 调用（支持路径参数绑定及 Query 自动拼装）
- 自适应路由（HTTP 与 gRPC 动态切换）
- 基础的统一错误映射（ApiException）
- 支持 Web & Native 编译兼容
```

---

## Phase 2: 服务治理与观测

支持：

```text
- 统一拦截器接口 (Auth, Logging)
- 自动重试机制 (指数退避与抖动)
- OpenTelemetry 链路追踪注入 (HTTP headers & gRPC metadata)
```

---

## Phase 3: 流式与高级传输协议

支持：

```text
- Server Streaming（gRPC Stream / HTTP SSE）
- ConnectRPC 协议（更优的 Web 跨平台通信）
- WebSocket（作为 HTTP 双向流的备用承载通道）
```

---

## Phase 4: 开发与测试生态

支持：

```text
- OpenAPI / Swagger 规范导出
- Mock 客户端与单元测试桩生成
```

---

# 最终目标

构建 Flutter 生态中的：

```text
ConnectRPC + Retrofit + gRPC + grpc-gateway
```

统一客户端生成器。

实现：

Proto First

↓

One Proto

↓

One SDK

↓

All Platforms

↓

One API

```
```
