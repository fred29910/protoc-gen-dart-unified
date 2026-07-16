## 1. Generator changes (remove pbgrpc dependency)

- [ ] 1.1 `service_generator.dart:_buildDirectives()` — remove `!_useHttp` branch that imports `../{proto}.pbgrpc.dart`; service file keeps only `unified_runtime.dart` + `*.pb.dart`
- [ ] 1.2 `service_generator.dart:_buildUnifiedImpl()` — remove `_grpcClient` field and `grpcClient` ctor param for gRPC services; `Unified<Service>` holds only `_transport` + `_interceptors`
- [ ] 1.3 `service_generator.dart:_buildGrpcUnaryCall()` — change to `_transport.unaryCall<Output>(...)` with `options: ctx.options`
- [ ] 1.4 `service_generator.dart:_buildGrpcServerStreamBody()` — change to `_transport.serverStream<Output>(...)` with `options: ctx.options`
- [ ] 1.5 `service_generator.dart:_buildApiSdk()` — accept user-provided `*ServiceClient`, build `GrpcClient` adapter (native-only), pass to `createTransport`; HTTP services pass `grpcClient: null`

## 2. Runtime changes (make gRPC truly usable + conditional isolation)

- [ ] 2.1 `runtime_inline_generator.dart` — delete `GrpcTransport` class from template; retain abstract `GrpcClient` + `createTransport` factory signature (no `grpc`/`dart:io` import)
- [ ] 2.2 `transport_native.dart:GrpcTransport.unaryCall` — ensure `executeWithInterceptors` wraps the chain (already present); `_rawGrpcUnaryCall` maps `RpcCallOptions.headers` → gRPC metadata, `timeout` → `CallOption.timeout`
- [ ] 2.3 `transport_native.dart:GrpcTransport.serverStream` — bridge `RpcCancelToken` to `ResponseFuture.cancel()`; map `RpcCallOptions.headers`/`timeout` to gRPC `CallOptions`
- [ ] 2.4 `transport_native.dart` — add `*ServiceClient → GrpcClient` adapter (native-only): `unaryCall`/`serverStream` delegate to `*ServiceClient` with `CallOptions` from `RpcCallOptions`
- [ ] 2.5 `transport_native.dart` — map `GrpcError` → `ApiException` by gRPC canonical code in `_rawGrpcUnaryCall` / `_rawGrpcServerStream`
- [ ] 2.6 `transport_factory.dart:createTransport` — confirm web path returns `HttpTransport` always; native returns `GrpcTransport` when `grpcClient != null`
- [ ] 2.7 `transport_web.dart` — confirm no `GrpcTransport` reference; add clear `UnsupportedError` when `grpcClient != null` on web

## 3. Testing & verification

- [ ] 3.1 Add gRPC-only fixture `test/fixtures/echo.proto` (no `google.api.http`)
- [ ] 3.2 Integration test: generate `echo_service.dart`, assert no `import '*.pbgrpc.dart'`, `UnifiedEcho` has no `_grpcClient` field, method body calls `_transport.unaryCall`
- [ ] 3.3 `transport_native_test.dart`: verify `GrpcTransport` delegation + error mapping with `TestGrpcClient` double
- [ ] 3.4 Web isolation check: `dart analyze` + conditional-import static check (or `dart compile js` smoke test) confirms no `grpc`/`dart:io` in web compile graph
- [ ] 3.5 `UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart` — sync golden; extend golden to cover gRPC-only scenario
- [ ] 3.6 `dart test` + `dart analyze --fatal-infos` all green

## 4. Docs & migration

- [ ] 4.1 `docs/usage.md` — declare Web does not support pure gRPC services; add regeneration migration note (breaking change)
- [ ] 4.2 Mark `docs/plan/2026-07-15-web-grpc-isolation.md` status as implemented (post-merge)
