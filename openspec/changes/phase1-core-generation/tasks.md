## 1. ExtensionRegistry + google.api.http Extraction

- [ ] 1.1 Vendor `google/api/http.pb.dart` and `google/api/annotations.pb.dart` into `lib/src/parser/google/api/`
- [ ] 1.2 Implement `createHttpExtensionRegistry()` to register `Annotations.http` extension
- [ ] 1.3 Implement `DescriptorParser._extractHttpRule()` with MethodOptions re-parse via `mergeFromBuffer(bytes, registry)`
- [ ] 1.4 Map extracted `HttpRule` to `HttpRuleModel` (kind, path, body, response_body, additional_bindings)
- [ ] 1.5 Add unit test: verify `google.api.http` annotation is correctly extracted (not silently lost)

## 2. HTTP Mapping Engine

- [ ] 2.1 Create `lib/src/builder/http_mapper.dart` with `HttpMapper` class
- [ ] 2.2 Implement path parameter interpolation (`{field}`, `{field=segments/*}` templates)
- [ ] 2.3 Implement query parameter flattening (non-path, non-body fields → query params)
- [ ] 2.4 Implement body mapping (`body: "*"`, `body: "field"`, no body)
- [ ] 2.5 Add unit tests for `HttpMapper` (path interpolation, query flattening, body mapping)

## 3. Code Generation with code_builder

- [ ] 3.1 Create `lib/src/generators/http_generator.dart` — generates HTTP transport calls using code_builder
- [ ] 3.2 Create `lib/src/generators/grpc_generator.dart` — generates gRPC delegation using code_builder
- [ ] 3.3 Create `lib/src/generators/facade_generator.dart` — generates unified service interface + implementation
- [ ] 3.4 Create `lib/src/generators/sdk_generator.dart` — generates `ApiSdk` entry class
- [ ] 3.5 Refactor `lib/src/generator.dart` to wire up all generators
- [ ] 3.6 Verify generated code passes `dart analyze` (zero errors)

## 4. Transport Implementation

- [ ] 4.1 Implement `HttpTransport` in `lib/src/runtime/transport_native.dart` (dio-based, unary only)
- [ ] 4.2 Implement `GrpcTransport` in `lib/src/runtime/transport_native.dart` (delegates to *ServiceClient)
- [ ] 4.3 Add `serverStream<T>()` to `Transport` abstract class
- [ ] 4.4 Implement `serverStream` for gRPC (native `ResponseStream`)
- [ ] 4.5 Implement `serverStream` for HTTP (throw `UnimplementedError`, Phase 3 SSE)
- [ ] 4.6 Implement `HttpTransport` for web in `lib/src/runtime/transport_web.dart`

## 5. Server Streaming Support

- [ ] 5.1 Update `MethodModel` to include `isServerStreaming` and `isClientStreaming` flags
- [ ] 5.2 Update `DescriptorParser` to detect streaming from `MethodDescriptorProto.clientStreaming` / `serverStreaming`
- [ ] 5.3 Update `FacadeGenerator` to emit `Stream<T>` return type for server streaming methods
- [ ] 5.4 Update `HttpGenerator` to emit server streaming method stubs

## 6. Golden Tests + Integration Tests

- [ ] 6.1 Create golden file `test/goldens/user_service.dart.golden` with expected output for `user.proto`
- [ ] 6.2 Update `test/golden/golden_test.dart` with real proto-to-Dart golden comparison
- [ ] 6.3 Add `--update-goldens` flag support to golden test
- [ ] 6.4 Add HTTP mapping unit tests (`test/builder/http_mapper_test.dart`)
- [ ] 6.5 Add ExtensionRegistry extraction test with real proto bytes
- [ ] 6.6 Add transport implementation tests (HttpTransport, GrpcTransport mocking)
- [ ] 6.7 Run `dart test` — all tests must pass
