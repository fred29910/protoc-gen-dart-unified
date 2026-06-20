## 1. Project Scaffold

- [x] 1.1 Create Dart package structure with `bin/`, `lib/`, `test/`, `analysis_options.yaml`, and `pubspec.yaml`
- [x] 1.2 Add latest compatible dependencies: `protoc_plugin 25.0.0`, `protobuf 6.0.0`, `dart_style 3.1.9`, `code_builder 4.11.1`, `args 2.7.0`, `dio 5.9.2`, `grpc 5.1.0`, `test 1.31.1`, `lints 6.1.0`
- [x] 1.3 Configure analyzer lints and SDK constraint `>=3.10.0 <4.0.0`

## 2. Generator Core

- [x] 2.1 Implement `bin/protoc_gen_dart_unified.dart` stdin/stdout entrypoint
- [x] 2.2 Implement descriptor traversal for files, services, and methods
- [x] 2.3 Add internal `ServiceModel`, `MethodModel`, `MessageModel`, and `HttpRuleModel`
- [x] 2.4 Implement `CodeGeneratorResponse` file generation for unary service facades

## 3. google.api.http Parsing

- [x] 3.1 Add `google/api/http.pb.dart` / `annotations.pb.dart` include handling or vendored fixture support
- [x] 3.2 Implement `ExtensionRegistry` registration and `MethodOptions` re-parse for `Annotations.http`
- [x] 3.3 Add custom option unit test proving `google.api.http` is not lost

## 4. HTTP Mapping and Runtime Contract

- [x] 4.1 Implement unary HTTP path interpolation for simple `{field}` placeholders
- [x] 4.2 Implement query flattening for non-path, non-body fields
- [x] 4.3 Add runtime `Protocol`, `ClientOptions`, `Transport`, `RpcInterceptor`, and `ApiException`
- [x] 4.4 Add gRPC code to HTTP status mapping table for all 17 canonical codes

## 5. Transport Splitting

- [x] 5.1 Create `transport_stub.dart`, `transport_native.dart`, and `transport_web.dart`
- [x] 5.2 Implement `transport_factory.dart` conditional import using `dart.library.io` and `dart.library.js_interop`
- [x] 5.3 Verify Web build does not import native gRPC transport

## 6. Golden Tests and Formatting

- [x] 6.1 Add fixture proto covering unary service with `google.api.http`
- [x] 6.2 Add golden output file for generated service facade
- [x] 6.3 Add DartFormatter idempotency test for generated source
- [x] 6.4 Run `dart format`, `dart analyze`, and `dart test` successfully
