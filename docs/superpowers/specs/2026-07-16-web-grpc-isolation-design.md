---
comet_change: web-grpc-isolation
role: technical-design
canonical_spec: openspec
archived-with: 2026-07-17-web-grpc-isolation
status: archived
---

# Design Doc: Web 端隔离 gRPC 代码（方案 A）

**Date**: 2026-07-16
**Change**: web-grpc-isolation

## 1. Problem Statement

纯 gRPC 服务（无 `google.api.http` 注解）生成的 `*_service.dart` 会无条件
`import '../{proto}.pbgrpc.dart'`，该 import 非条件、不区分平台 → Web 编译引入
`grpc`/`dart:io`，构建失败。根因有两层：

1. **Service 生成层**：`service_generator.dart` 为纯 gRPC service 静态生成 pbgrpc import。
2. **Runtime 模板层**：原单文件 `unified_runtime.dart` 模板内直接定义 `GrpcTransport`
    实现（依赖 `grpc`/`dart:io`）。Dart 条件导入仅在文件级工作，无法在文件内用
    `#if` 隔离代码块 → Web 必然编译进 gRPC 实现。

> **实现决策演进（已确认）**：方案 A 已演进为 **A1**——`unified_runtime.dart`
> 不再内联 gRPC 实现，改为由 5 文件 runtime 集合经条件导入隔离
> （`unified_runtime.dart` + `unified_transport_{factory,native,web,stub}.dart`）。
> 适配器形态采用 **O-C**：全局 `unified_transport_native.dart` 保持无参
> （含通用 `GrpcTransport` + `createTransport` + `_mapGrpcError` + cancel 桥接），
> **新增 per-service `unified_transport_adapter_{service}.dart`**（逐方法 switch
> 分发到真实 `*ServiceClient` 具名方法，native-only，携带唯一 pbgrpc import）。

运行时层的条件导入（`transport_factory.dart`）已正确隔离，但 service 层与
生成 runtime 层仍有泄漏。

## 2. Architecture Overview

```
生成产物（每个 service）:
  user_service.dart                    ← 只 import unified_runtime.dart + user.pb.dart
  unified_transport_adapter_user.dart  ← per-service gRPC 适配器（native-only，唯一 pbgrpc import）
  unified_runtime.dart                 ← 条件导入此层隔离 gRPC（仅含抽象接口 + 工厂 re-export）

运行时编译单元（lib/src/runtime/ 生成集）:
  unified_runtime.dart               ← re-export 工厂 + abstract GrpcClient + Protocol
  unified_transport_factory.dart     ← 条件导入分发
    ├─ dart.library.io      → unified_transport_native.dart  (HttpTransport + GrpcTransport + _mapGrpcError)
    └─ dart.library.js_interop → unified_transport_web.dart   (仅 HttpTransport, grpcClient!=null 时 throw)
  unified_transport_stub.dart        ← 非 io/非 js 平台的默认（UnsupportedError）
  unified_transport_adapter_user.dart ← per-service：{Service}GrpcAdapter 实现 GrpcClient，逐方法 switch 分发到 *ServiceClient
```

- `GrpcTransport` 仅存在于 `unified_transport_native.dart`（native 编译单元）
- Web 因条件导入不编译 `unified_transport_native.dart` / `unified_transport_adapter_*.dart`，
  自然不碰 `grpc`/`dart:io`
- service 文件不再 `import *.pbgrpc.dart`，gRPC 依赖完全隔离在 native-only 模块
  （全局 native 文件 + per-service adapter 文件）

## 3. Generator Layer Changes (`service_generator.dart`)

### 3.1 Directives (`_buildDirectives`)
移除 `!_useHttp` 分支的 `import '../{proto}.pbgrpc.dart'`。service 文件保留：
- `import 'unified_runtime.dart'`
- `import '{proto}.pb.dart'`

### 3.2 Unified Impl (`_buildUnifiedImpl`)
移除 `_grpcClient` 字段与 `grpcClient` 构造参数。`Unified<Service>` 仅持有
`_transport`（`Transport`）与 `_interceptors`（`List<RpcInterceptor>`）。

### 3.3 Call Bodies
- `_buildGrpcUnaryCall` → `_transport.unaryCall<Output>(svc, m, request, options: ctx.options)`
- `_buildGrpcServerStreamBody` → `_transport.serverStream<Output>(svc, m, request, options: ctx.options)`

### 3.4 ApiSdk (`_buildApiSdk`)
- 接收用户提供的 `*ServiceClient`（native 下可用）
- 经 `GrpcClientAdapter` 转为 `GrpcClient` 后传给 `createTransport`
- HTTP 服务 `grpcClient` 传 `null` → `createTransport` 返回 `HttpTransport`

## 4. Runtime Template Changes (`runtime_inline_generator.dart`)

删除模板中的 `GrpcTransport` 类（原第 617-662 行）。保留：
- `abstract class GrpcClient`（`unaryCall` / `serverStream`）
- `Transport? createTransport(endpoint, {GrpcClient? grpcClient, ...})` 工厂签名
- 不含 `grpc` / `dart:io` import

## 5. Runtime Implementation Changes (`transport_native.dart`, native-only)

### 5.1 GrpcTransport 拦截器链
`unaryCall` / `serverStream` 经 `Transport.executeWithInterceptors` 套拦截器链
（已实现）。

### 5.2 RpcCallOptions → gRPC CallOptions 映射
在 `_rawGrpcUnaryCall` / `_rawGrpcServerStream` 中构造 gRPC `CallOptions`：
- `options.headers` → `CallOption.metadata(headers)`（gRPC metadata）
- `options.timeout` → `CallOption.timeout(timeout)`
- `options.cancelToken` → `cancelToken.onCancel(() => responseFuture.cancel())`
  （onCancel 回调桥接到 `ResponseFuture.cancel()`，轻量无额外线程）

### 5.3 GrpcError → ApiException
捕获 `GrpcError`，按 `code` 映射 canonical code → `ApiException` 子类
（复用 `HttpTransport._createApiException` 相同的 code→exception 表）。

### 5.4 GrpcClientAdapter（泛型适配器类）
```dart
class GrpcClientAdapter implements GrpcClient {
  final dynamic _client;  // *ServiceClient from protoc-gen-dart
  GrpcClientAdapter(this._client);
  @override
  Future<T> unaryCall<T>(String svc, String m, Object req, {RpcCallOptions? options}) =>
      _client.$(m)<T>(req, options: _toCallOptions(options));
  @override
  Stream<T> serverStream<T>(String svc, String m, Object req, {RpcCallOptions? options}) =>
      _client.$(m)<T>(req, options: _toCallOptions(options));
}
```
仅依赖 `*ServiceClient` 的 `unaryCall` / `serverStream` 标准签名，最小化耦合。
（`$(m)` 表示按方法名动态分派——实际实现中由生成代码为每个方法显式委托，
adapter 提供通用转换工具 `_toCallOptions`；生成级逐方法委托见 §3.4 注释。）

## 6. Web Failure Detection (`transport_web.dart`)

`createTransport` 的 web 分支：
```dart
if (grpcClient != null) {
  throw UnsupportedError(
    'Web platform does not support pure gRPC services. '
    'Add google.api.http annotations to enable HTTP/REST, '
    'or use a native platform.',
  );
}
return HttpTransport(endpoint, interceptors: interceptors);
```

## 7. Testing Strategy

- **Fixture**：新增 `test/fixtures/echo.proto`（无 `google.api.http`）
- **Integration test**：生成 `echo_service.dart`，断言：
  - 不含 `import '*.pbgrpc.dart'`
  - `UnifiedEcho` 无 `_grpcClient` 字段
  - 方法体调用 `_transport.unaryCall`
- **`transport_native_test.dart`**：用 `TestGrpcClient` 双验证 `GrpcTransport`
  委托 + `GrpcError` → `ApiException` 映射 + options 透传
- **Web 隔离验证（任务 3.4，已实现）**：`test/web_isolation_test.dart` 双断言——
  (a) 生成全量文件，**排除** native transport + per-service adapter 后写入临时工程，
  `dart analyze --fatal-infos` 必须全绿（即 web 编译集在无 `grpc`/`dart:io` 下可编译）；
  (b) 遍历所有生成文件，仅 native/adapter 文件允许 `import grpc`/`dart:io`/`pbgrpc`，
  其余文件一律禁止。per-service adapter 本身另由 `runtime_inline_generator_test.dart`
  的 `generateTransportAdapter() compiles against stub pbgrpc` 实际编译验证。
- **Golden**：`UPDATE_GOLDENS=1` 同步 + 扩展 gRPC-only 场景断言
- **Gate**：`dart test` + `dart analyze --fatal-infos` 全绿

## 8. Migration & Docs

- 所有存量生成代码需一次性重新生成（破坏性变更）
- `docs/usage.md`：声明 Web 不支持纯 gRPC 服务 + 重新生成迁移说明
- `docs/plan/2026-07-15-web-grpc-isolation.md` 状态标记 implemented（post-merge）

## 9. Open Questions (resolved)

- Web `dart:io` 泄漏检测手段 → 采用静态文本断言 + `dart analyze`（非编译 smoke test）
- 适配器形态 → 泛型 `GrpcClientAdapter` 类（生成代码逐方法委托）
- Cancel 桥接 → `onCancel` 回调桥接 `ResponseFuture.cancel()`
- Web 失败检测 → `transport_web.dart` 显式 `throw UnsupportedError`
