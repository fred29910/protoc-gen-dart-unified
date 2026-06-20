# protoc-gen-dart-unified

> 面向 Flutter 全平台（Web / Android / iOS / Desktop）的统一 RPC SDK 生成器

## 项目目标

`protoc-gen-dart-unified` 是一个基于 Protocol Buffers 的 Dart/Flutter 客户端代码生成器。

设计目标：

* 支持 HTTP(JSON / google.api.http) 与 gRPC(Protobuf)
* Flutter Web 自动使用 HTTP
* Flutter Native 自动支持 gRPC
* 支持运行时切换协议
* 调用端完全无感底层协议
* 单文件生成（必要时降级多文件）
* 支持 grpc-gateway / google.api.http 注解
* 支持拦截器
* 支持 Streaming
* 支持 OpenTelemetry（轻量注入）
* 支持未来 ConnectRPC 扩展

---

## 立项前提：为什么不直接用 connect-dart？

社区已有 [connect-dart](https://github.com/connectrpc/connect-dart)（v1.0.0），它提供"一套 API + 多 transport（Connect / gRPC / gRPC-Web）+ 协议无感"的能力，与本项目目标高度重叠。我们仍然自研，原因与边界如下：

| 维度 | connect-dart | 本项目的取舍 |
| --- | --- | --- |
| HTTP 协议形态 | 自有 `POST /Service/Method` 信封协议 | **后端是 grpc-gateway，需要真正的 RESTful 路径**（`GET /v1/users/{id}`），connect 无法对接 |
| gRPC | 自带 gRPC / gRPC-Web 实现 | **不重复造**，gRPC 侧复用官方 `protoc-gen-dart` 产物 |
| 定位 | 通用 Connect 客户端 | 绑定 `google.api.http`，服务 Kratos / grpc-gateway 风格后端 |

**核心结论（三条决策）：**

1. **HTTP/REST 路由自研** —— 因为必须绑定 `google.api.http` 注解，实现真正的 RESTful 路径映射，这是 connect-dart 不覆盖的部分。
2. **gRPC 侧复用现成实现** —— 直接委托官方 `protoc-gen-dart` 生成的 `*.pbgrpc.dart`，不手搓 `ClientChannel` / marshalling / 流式。
3. **插件本体用 Dart 编写** —— 与产物及整个项目同语言，单语言维护；基于 `protoc_plugin` 提供的 `CodeGeneratorRequest/Response` 与 descriptor 基建解析，不手写 wire 解析；用 `dart_style` 在进程内格式化产物，再以 `dart analyze` 做 lint 门禁。

ConnectRPC 仍作为 **Phase 3 的可选 transport 来源**（gRPC-Web / Connect 协议），届时直接复用其实现而非自研。

---

# 设计原则

## 统一接口

业务代码永远不关心：HTTP / gRPC / grpc-web / SSE。

调用方式始终一致：

```dart
final userService = sdk.userService;

final user = await userService.getUser(
  GetUserRequest(id: 1),
);
```

---

## 环境自动识别（编译期决定，而非运行时）

> ⚠️ 关键修正：环境选择必须在 **编译期** 通过 conditional import 完成，**不能** 仅靠运行时 `if (kIsWeb)` 分支。
> 原因：只要文件里出现 `import 'package:grpc/grpc.dart'`，无论运行时分支如何，grpc 都会被打进 Web 产物，Tree-Shaking 无法移除。详见《传输层切分与 Tree Shaking》。

### Browser

自动使用 `HTTP(JSON)`，原因：grpc-web 限制多、代理/CORS 复杂、部署成本高。

### Native（Android / iOS / macOS / Windows / Linux）

允许 `Protocol.grpc` 与 `Protocol.http`，可动态切换。

### Protocol.auto 的判定规则（必须明确）

| 运行环境 | transport 配置 | auto 实际选择 |
| --- | --- | --- |
| Web | 任意 | **http**（强制） |
| Native | 含 grpc | **grpc**（优先） |
| Native | 仅 http | http |

判定在编译期（平台）+ 构造期（配置）确定，运行时不再做协议探测。

---

## 协议无感知

业务代码 `await userService.getUser(...)` 底层可能是 HTTP 或 gRPC，由生成的 `UnifiedService` 按上表自动路由。

---

# 技术选型

## 插件本体（Generator）

**语言：Dart。** 插件是一个可执行程序：从 stdin 读取 `CodeGeneratorRequest`，向 stdout 写出 `CodeGeneratorResponse`。复用官方基建，避免手写 wire 解析：

```yaml
# 插件工程依赖（pubspec.yaml）
protoc_plugin: ^21.x   # 提供 plugin.pb.dart / descriptor.pb.dart，以及 protoc-gen-dart 复用基建
protobuf:     ^4.x     # 运行时与 descriptor 解析
code_builder: ^4.x     # 以 AST 构建 Dart 代码（替代字符串模板，天然合法、易维护）
dart_style:   ^2.x     # DartFormatter：进程内格式化产物
args:         ^2.x     # 解析 --dart-unified_opt 插件参数
```

### ⚠️ 读取 google.api.http（custom option）是关键风险点

`google.api.http` 是 **custom option**，Dart protobuf 对其读取较弱（历史上需手动处理，见 protobuf.dart#341）。落地方式：

1. 用 `protoc-gen-dart` 预先生成 `google/api/http.pb.dart`、`annotations.pb.dart`，获得 `Annotations.http` 扩展（field 72295728）。
2. 解析 request 时构造 `ExtensionRegistry` 并注册该扩展，对 `MethodOptions` 以 `mergeFromBuffer(bytes, registry)` 重解析，再 `getExtension(Annotations.http)` 取出 `HttpRule`。

> 此处必须有针对性的单元测试覆盖，否则注解会以 unknown fields 形式被静默丢弃。

错误码 ↔ HTTP 状态码映射 **对齐 grpc-gateway 的 `runtime.HTTPStatusFromCode`**：以一张移植自其规则的常量表实现（17 个 canonical code 全覆盖），Dart 端无对应库，故内置该映射表。

### 生成后处理（强制）

* **格式化**：用 `DartFormatter().format(source)` 在 **进程内** 完成，无需 shell 调用 `dart format`，更快且无外部依赖。
* **Lint 门禁**：CI 中对产物执行 `dart analyze`（配合 `package:lints` / `flutter_lints`），要求零告警。

格式化或 lint 失败应作为 CI 硬性门禁，保证产物始终可读、可编译、零告警。

---

## Message

官方 protobuf 实现，由 `protoc-gen-dart` 生成 `user.pb.dart`：

```yaml
protobuf: ^4.x
```

生成的统一服务文件 **import 导入** 官方消息模型，绝不内联 Message 定义（避免重复实现序列化与未知字段处理）。

---

## gRPC Client（复用现成产物，不自研）

gRPC 侧直接复用 `protoc-gen-dart` 的 grpc 产物：

```bash
protoc --dart_out=grpc:lib/generated user.proto   # 生成 user.pbgrpc.dart（含 UserServiceClient / ResponseStream<T>）
```

```yaml
grpc: ^4.x
```

`GrpcTransport` 仅 **委托** 给生成的 `UserServiceClient`，复用其 marshalling、metadata、四种流式语义，不裸用 `ClientChannel`。

---

## HTTP Client（REST 路由自研）

```yaml
dio: ^5.x   # 默认；如需 Web 端流式 body（SSE）可评估 package:http + fetch_client
```

> 说明：Unary 场景 dio 完全够用；但 SSE 需逐块读取响应体，dio 在 Web(XHR) 下支持有限，Phase 3 流式落地前需评估替换为 `package:http`。

HTTP 侧自研 `HttpTransport`，负责 `google.api.http` 的完整 transcoding（见《HTTP Mapping》）。

---

## Runtime Detection

环境判定优先支持纯 Dart 环境（CLI / 服务端），避免强依赖 Flutter。
编译期通过 conditional import 区分平台；`kIsWeb` 仅作运行时兜底：

```dart
// 纯 Dart 兜底（JS 不区分 int/double）
const bool kIsWeb = identical(0, 0.0);
// Flutter 工程优先：import 'package:flutter/foundation.dart' show kIsWeb;
```

---

## Serialization

优先 `protobuf binary`，兼容 `json`。JSON 兼容使用官方 `protobuf` 库内置方法，确保 Well-Known Types（Timestamp、Any 等）与 `json_name` 字段命名的严格契约转换：

```dart
Message.toProto3Json()
Message.mergeFromProto3Json()
Message.writeToBuffer()
Message.fromBuffer()
```

---

## Logging（不硬依赖具体库）

runtime 包只定义 `RpcInterceptor` 接口；`LoggingInterceptor` 作为 **可选附属包**，由用户决定接入 `logger` 或自有日志，核心 runtime 不引入日志依赖。

---

## OpenTelemetry（默认仅注入 traceparent）

Dart 的 `opentelemetry` 仍处 0.x、API 不稳定，**不进核心 runtime**。

* 默认能力：注入 W3C `traceparent` header（HTTP）/ metadata（gRPC），实现极轻量。
* 完整 OTel SDK（Jaeger / Tempo / Zipkin / OTLP）作为可选插件接入，由用户显式启用。

---

# 插件架构

```text
proto
   │  ▼
protoc-gen-dart-unified (Dart 可执行)
   │  ▼
Generated SDK  →  DartFormatter（进程内）+ dart analyze（CI 门禁）
```

---

# Generator Architecture（Dart）

```text
lib/
├── parser/        // 遍历 CodeGeneratorRequest 的 descriptor + ExtensionRegistry 读取 google.api.http
├── model/         // 统一内部模型
├── builder/       // 基于 code_builder 的 Dart AST 构建（替代字符串模板）
├── generators/    // 各产物生成器
└── runtime/       // 生成 SDK 依赖的 Dart 运行时（独立发布的 package）
bin/
└── protoc_gen_dart_unified.dart   // 入口：stdin → CodeGeneratorRequest，stdout → CodeGeneratorResponse
```

## parser

直接遍历 `CodeGeneratorRequest` 携带的 `FileDescriptorProto`（含传递依赖），逐个处理 service / method；用注册了 `Annotations.http` 扩展的 `ExtensionRegistry` 读取 `google.api.http`，**不手写 wire 解析**（见上文风险点）。

## model

```text
ServiceModel / MethodModel / MessageModel / HttpRuleModel
```

`HttpRuleModel` 须承载完整 HttpRule 语义（见 HTTP Mapping 的能力清单）。

## builder / generators

各 generator 通过 `code_builder` 构造 AST，最后由 `DartFormatter` 统一格式化输出：

```text
GrpcGenerator    // 包装 *.pbgrpc.dart 的薄委托
HttpGenerator    // 自研 REST transcoding
FacadeGenerator  // 统一服务接口 + Unified 实现
SdkGenerator     // ApiSdk 入口
```

## runtime

生成 SDK 依赖的运行时（`Protocol` / `Transport` / `ClientOptions` / `RpcInterceptor` / `ApiException`）。

---

# 支持的 Proto 特性

| RPC 类型 | Proto | 生成 | gRPC | HTTP/JSON |
| --- | --- | --- | --- | --- |
| Unary | `rpc GetUser(Req) returns(User)` | `Future<User>` | 复用 pbgrpc | REST transcoding |
| Server Streaming | `returns(stream User)` | `Stream<User>` | 原生 `ResponseStream` | SSE（Phase 3） |
| Client Streaming | `rpc Upload(stream ..)` | `Future<Resp>` | 原生 `RequestStream` | 不支持，抛 `UnsupportedError`（Phase 3 WebSocket/Connect） |
| Bidi Streaming | `(stream) returns(stream)` | `Stream<Message>` | 原生 Bidi | 同上 |

---

# HTTP Mapping（自研，需完整覆盖 HttpRule）

基础映射：

```proto
option (google.api.http) = { get: "/v1/users/{id}" };
```

```dart
dio.get("/v1/users/$id");
```

方法映射：

| Proto | HTTP |
| ----- | ---- |
| get / post / put / patch / delete | GET / POST / PUT / PATCH / DELETE |

## 能力清单（必须实现，避免遗漏）

* **路径参数绑定**：`{id}`、`{name=segments/*}` 模板展开；路径变量不得为 repeated/map 字段。
* **Query 自动展平**：未被路径绑定且未进 body 的字段 → URL Query；嵌套 message 按 grpc-gateway 规范点号展开。
* **Body 映射**：`body: "*"`（整个 request 作为 body）、`body: "field"`（指定子字段作为 body）、无 body（GET/DELETE）。
* **`response_body`**：将响应中指定字段作为 HTTP body 解析。
* **`additional_bindings`**：同一 rpc 多路由绑定。
* **Well-Known Types 编码**：Timestamp/Duration/FieldMask 等作为 path/query 参数时遵循 proto3 JSON 编码规则。

> 转换严格遵循 gRPC-Gateway 规范，并以其行为作为 golden 测试基准。

---

# SDK Runtime（独立轻量 package）

底层 `Protocol` / `Transport` / `RpcInterceptor` / `ApiException` 抽离为独立 Dart package（如 `protoc_gen_dart_unified_runtime`），所有生成代理统一依赖之，避免多服务生成时类型冲突与冗余。

```dart
enum Protocol { auto, http, grpc }

class ClientOptions {
  final String endpoint;
  final Protocol protocol;
  final Duration? timeout;          // 统一超时
}

final sdk = ApiSdk(
  ClientOptions(endpoint: "https://api.example.com", protocol: Protocol.auto),
);
```

---

# Transport 抽象

```dart
abstract class Transport {
  Future<T> unaryCall<T>(
    MethodDescriptor descriptor,
    Object request, {
    RpcCallOptions? options,   // 统一 headers/metadata、deadline、cancel
  });

  Stream<T> serverStream<T>(MethodDescriptor descriptor, Object request, {RpcCallOptions? options});
}
```

* **统一取消**：`RpcCallOptions` 携带取消句柄；HTTP 内部转 `CancelToken`，gRPC 转原生 cancel（借鉴 connect 的 AbortSignal 语义）。
* **统一超时（Deadline）**：跨 transport 一致语义，映射到 `DEADLINE_EXCEEDED` / 504。

## HTTP 实现

```dart
class HttpTransport implements Transport   // 内部：dio + json + google.api.http transcoding
```

## gRPC 实现

```dart
class GrpcTransport implements Transport    // 内部：委托 *.pbgrpc.dart 的 *Client
```

---

# Unified Service

```dart
abstract class UserService {
  Future<User> getUser(GetUserRequest request);
}

class UnifiedUserService implements UserService {
  // 按 Protocol.auto 判定规则路由到 HttpTransport / GrpcTransport
}
```

---

# 单文件生成模式

目标产物：`user_service.dart`，包含 Facade & Unified 接口、SDK 入口、Descriptor。

约束：

* **import 官方 `user.pb.dart`**，不内联 Message。
* gRPC 委托 `user.pbgrpc.dart`，不重写 gRPC client。

## 传输层切分与 Tree Shaking（关键）

> 单文件 + 强 Tree-Shaking 存在天然张力。最终方案：**核心单文件 + 两个 transport 分片文件**，通过 conditional import 编译期选择。

```dart
// transport_factory.dart
import 'transport_stub.dart'
    if (dart.library.io) 'transport_native.dart'        // 含 grpc
    if (dart.library.js_interop) 'transport_web.dart';  // 仅 http
```

这样：

* Web 编译时根本不引用 `transport_native.dart`，`grpc` 包不进产物。
* 当 `transport=http` 时，连 native 分片都不生成，彻底无 grpc import。

替代旧方案中失效的运行时 `if (kIsWeb)` 包体裁剪。避免 20+ 碎片文件，但保留必要的 transport 切分。

---

# Interceptor 系统

```dart
abstract class RpcInterceptor { /* 避免与 dio/grpc 的 Interceptor 命名冲突 */ }
```

支持：Auth / Retry / Logging / Metrics / Tracing / Cache。

```dart
sdk.addInterceptor(AuthInterceptor(tokenProvider));   // 统一注入 HTTP header 与 gRPC metadata
```

---

# Retry 机制

```dart
RetryPolicy(maxAttempts: 3)   // Exponential Backoff + Jitter
```

---

# Error Mapping

Transport 层捕获底层异构异常（DioException / GrpcError），映射到统一 `ApiException` 体系。映射规则以 **移植自 grpc-gateway `HTTPStatusFromCode` 的常量表** 实现（Dart 端无对应库，故内置），覆盖全部 17 个 canonical gRPC code（下表为常用子集）。

```dart
abstract class ApiException implements Exception {
  final String message;
  final int? code;   // 统一错误码（对齐 google.rpc.Code）
  ApiException(this.message, [this.code]);
}
```

| 业务场景 | gRPC code | HTTP | 统一异常 |
| :--- | :--- | :--- | :--- |
| 参数验证错误 | INVALID_ARGUMENT (3) | 400 | `InvalidArgumentException` |
| 未身份验证 | UNAUTHENTICATED (16) | 401 | `UnauthenticatedException` |
| 权限不足 | PERMISSION_DENIED (7) | 403 | `PermissionDeniedException` |
| 资源未找到 | NOT_FOUND (5) | 404 | `NotFoundException` |
| 频率超限 | RESOURCE_EXHAUSTED (8) | 429 | `ResourceExhaustedException` |
| 服务端内部错误 | INTERNAL (13) | 500 | `InternalServerException` |
| 网络/截止超时 | DEADLINE_EXCEEDED (4) | 504 | `RpcTimeoutException`（避免与 dart:async `TimeoutException` 冲突） |

> 其余 code（CANCELLED / UNKNOWN / NOT_FOUND / ALREADY_EXISTS / ABORTED / OUT_OF_RANGE / UNIMPLEMENTED / UNAVAILABLE / DATA_LOSS / FAILED_PRECONDITION）均须有对应异常类型与 HTTP 映射。

---

# OpenTelemetry

默认仅注入 W3C `traceparent`（HTTP header / gRPC metadata）。完整 Span/TraceContext 由可选 OTel 插件提供。

---

# Streaming 设计

统一对业务层暴露 `Stream<T>`，底层支持度：

* **Server Streaming**：gRPC 用原生 `ResponseStream`；HTTP/JSON 用 **SSE**（分块读取响应体，Phase 3）。
* **Client / Bidi Streaming**：gRPC 原生支持；HTTP/JSON 降级方案不支持流式写入（抛 `UnsupportedError`），Phase 3 通过 **WebSocket / ConnectRPC(HTTP/2)** 实现。

---

# 生成示例

```proto
service UserService {
  rpc GetUser(GetUserRequest) returns(User) {
    option (google.api.http) = { get: "/v1/users/{id}" };
  }
}
```

```dart
final sdk = ApiSdk(options);
final user = await sdk.userService.getUser(GetUserRequest(id: 1));
// 业务层无需关心 HTTP / gRPC / Web / Android / iOS / Desktop
```

---

# 插件参数

```bash
protoc \
  --dart-unified_out=. \
  --dart-unified_opt=single_file=true,protocol=auto,transport=http,grpc
```

| 参数 | 默认 | 说明 |
| ----------- | --------- | ------------- |
| single_file | true | 单文件生成（Proto 庞大时设 false 降级多文件） |
| protocol | auto | 默认协议（auto 判定见上表） |
| transport | http,grpc | 支持协议（仅 http 时不生成 native 分片，彻底无 grpc import） |
| use_dio | true | Dio 客户端 |
| tracing | true | 注入 traceparent |
| interceptor | true | 拦截器 |
| retry | true | 自动重试 |
| format | true | 进程内 DartFormatter 格式化产物 |
| lint | true | 产物交由 CI 的 dart analyze 校验 |

> 推荐使用 [buf](https://buf.build)（`buf.gen.yaml` + managed mode + 远程插件）替代裸 protoc，降低接入成本并便于 golden 测试。
>
> 插件以 Dart 编写，安装即 `dart pub global activate`（或 `dart compile exe` 产出单文件二进制供 CI/无 Dart SDK 环境使用）。

---

# 测试策略（生成器自身）

protoc 插件须以 **golden-file 测试** 为核心（与官方 `protoc_plugin` 仓库一致的做法），用 `package:test` 驱动：

* `test/goldens/`：固定输入 proto → 期望输出 Dart（提供更新模式刷新基线）。
* fixture：基于 buf 构建，覆盖 Unary / 各类流式 / 完整 HttpRule（body / additional_bindings / response_body / WKT query）。
* **专项测试**：custom option（`google.api.http`）能被 `ExtensionRegistry` 正确读出，防止静默丢失。
* 产物须通过 `DartFormatter` 幂等校验与 `dart analyze`（零告警）作为 CI 门禁。
* 以 grpc-gateway 行为作为 transcoding 的对照基准。

---

# 未来规划

## Phase 1: MVP 核心骨架

```text
- Dart 插件骨架（stdin/stdout + protoc_plugin 基建）+ golden 测试脚手架（地基，后补成本极高）
- 打通 google.api.http custom option 读取（ExtensionRegistry）+ 专项测试
- Unary 调用（google.api.http 路径绑定 + Query 展平 + body 映射）
- conditional-import 的 transport 切分（编译期 Tree-Shaking）
- 自适应路由（Protocol.auto 明确判定规则）
- 基础统一错误映射（ApiException，移植 HTTPStatusFromCode 表）
- Web & Native 编译兼容
- 产物 DartFormatter 格式化 + dart analyze
```

## Phase 2: 服务治理与观测

```text
- 统一拦截器接口（Auth, Logging）
- 自动重试（指数退避 + 抖动）
- 统一取消 / 超时
- traceparent 注入（HTTP header & gRPC metadata）
```

## Phase 3: 流式与高级传输协议

```text
- Server Streaming（gRPC 原生 / HTTP SSE，优先评估复用 connect-dart 而非自研 SSE）
- ConnectRPC 协议（gRPC-Web / Connect transport，复用 connect-dart）
- WebSocket（HTTP 双向流备用承载）
```

## Phase 4: 开发与测试生态

```text
- OpenAPI / Swagger 导出（可复用 protoc-gen-openapiv2 产物，不自研）
- Mock 客户端与单测桩生成
```

---

# 最终目标

构建 Flutter 生态中的 `ConnectRPC + Retrofit + gRPC + grpc-gateway` 统一客户端生成器：

```text
Proto First → One Proto → One SDK → All Platforms → One API
```
