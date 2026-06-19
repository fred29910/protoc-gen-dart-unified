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

使用：

```dart
import 'package:flutter/foundation.dart';
```

判断：

```dart
kIsWeb
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

生成：

```dart
Message.fromJson()
Message.writeToBuffer()
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

---

# SDK Runtime

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

```text
Message
Descriptor
HttpClient
GrpcClient
Facade
SDK入口
```

避免：

```text
20+
碎片文件
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

统一异常：

```dart
ApiException
```

映射：

```text
HTTP 404
gRPC NOT_FOUND
```

↓

```dart
NotFoundException
```

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

HTTP：

```text
SSE
```

gRPC：

```text
Server Stream
```

统一：

```dart
Stream<T>
```

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
| single_file | true      | 单文件生成         |
| protocol    | auto      | 默认协议          |
| transport   | http,grpc | 支持协议          |
| use_dio     | true      | Dio客户端        |
| tracing     | true      | OpenTelemetry |
| interceptor | true      | 拦截器           |
| retry       | true      | 自动重试          |

---

# 未来规划

## Phase 1

MVP

支持：

```text
Unary
HTTP
gRPC
Web
Mobile
```

---

## Phase 2

支持：

```text
Streaming
Retry
Interceptor
OpenTelemetry
```

---

## Phase 3

支持：

```text
ConnectRPC
grpc-web
WebSocket
SSE
```

---

## Phase 4

支持：

```text
OpenAPI生成
Swagger生成
Mock生成
测试桩生成
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
