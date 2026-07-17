## 1. Generator changes (remove pbgrpc dependency) — DONE

- [x] 1.1 `service_generator.dart:_buildDirectives()` — remove `!_useHttp` branch that imports `../{proto}.pbgrpc.dart`; service file keeps only `unified_runtime.dart` + `*.pb.dart` (commits 36561aa, 99d6281)
- [x] 1.2 `service_generator.dart:_buildUnifiedImpl()` — remove `_grpcClient` field and `grpcClient` ctor param; `Unified<Service>` holds only `_transport` + `_interceptors` (dfeba04)
- [x] 1.3 `service_generator.dart:_buildGrpcUnaryCall()` — change to `_transport.unaryCall<Output>(...)` with `options: ctx.options` (6463f50)
- [x] 1.4 `service_generator.dart:_buildGrpcServerStreamBody()` — change to `_transport.serverStream<Output>(...)` with `options: ctx.options` (1af9b15)
- [x] 1.5 `service_generator.dart:_buildApiSdk()` — accept `GrpcClient? grpcClient`, pass to `createTransport`; `Unified` constructed with 2 args (2723015) — adapter wiring moved to per-service adapter file (O-C)

## 2. Runtime changes (conditional isolation, A1: 5-file set) — DONE

- [x] 2.1 `runtime_inline_generator.dart` — `generate()` strips `GrpcTransport` + inline `createTransport`; re-exports factory; retains abstract `GrpcClient` + `Protocol` (60408e8)
- [x] 2.2 `runtime_inline_generator.dart` — add `generateTransportFactory/Native/Web/Stub`; emit 5-file set (60408e8)
- [x] 2.3 `generator_registry.dart` — register 4 global transport generators → 5 runtime files/request (385f235)
- [x] 2.4 `runtime_inline_generator.dart:generateTransportNative()` — `GrpcTransport` (native-only) maps `RpcCallOptions.headers`→gRPC metadata, `timeout`→`CallOption.timeout`; `_mapGrpcError` maps `GrpcError`→`ApiException` (9a66309)
- [x] 2.5 cancel bridge — `RpcCancelToken.onCancel` → `ResponseFuture.cancel()` in `_rawGrpcUnaryCall` (9a66309)
- [x] 2.6 `generateTransportAdapter(ServiceModel)` — NEW per-service adapter file (O-C): `{Service}GrpcAdapter implements GrpcClient`, per-method switch delegating to real `*ServiceClient`; `_toCallOptions` maps `RpcCallOptions`→gRPC `CallOptions`; native-only, carries the only pbgrpc import (9a66309)
- [x] 2.7 `generator_registry.dart` — `TransportAdapter` registered perService → `unified_transport_adapter_{name}.dart` (6d4a40c)
- [x] 2.8 web file — `generateTransportWeb()` returns `HttpTransport` always; `UnsupportedError` when `grpcClient != null` (60408e8)

## 3. Testing & verification — DONE

- [x] 3.1 `test/fixtures/echo.proto` (gRPC-only, no `google.api.http`) exists
- [x] 3.2 Integration test: `echo_service.dart` no `*.pbgrpc.dart` import, no `_grpcClient`, calls `_transport.unaryCall` (generator_integration_test.dart)
- [x] 3.3 `test/transport_native_test.dart` — behavioral: generates real native+adapter, compiles against stub pbgrpc, harness verifies per-method delegation + options mapping + `GrpcError.notFound`→`NotFoundException` + server-streaming (639a7a5)
- [x] 3.4 Web isolation — `test/web_isolation_test.dart`: web-safe file set (excludes native+adapter) analyzes clean WITHOUT grpc/dart:io; no non-native file imports grpc/dart:io/pbgrpc (690ae00)
- [x] 3.5 adapter compile-check — `runtime_inline_generator_test.dart` compiles generated adapter against stub pbgrpc (690ae00)
- [x] 3.6 full suite 176 green; `dart analyze lib/` shows only 3 pre-existing info issues, none introduced

## 4. Docs & migration — DONE

- [x] 4.1 `docs/usage.md` §6.2 — Web unsupported pure gRPC + regeneration migration note; removed stale single-file transport note (5da7c46)
- [x] 4.2 Design doc `docs/superpowers/specs/2026-07-16-web-grpc-isolation-design.md` §1/§2/§7 synced to A1 + O-C; spec `web-grpc-build-isolation/spec.md` aligned to 5-file set (b6f233d, 65d5756)
