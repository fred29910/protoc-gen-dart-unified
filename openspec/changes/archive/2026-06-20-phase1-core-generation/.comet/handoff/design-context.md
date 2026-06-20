# Comet Design Handoff

- Change: phase1-core-generation
- Phase: design
- Mode: compact
- Context hash: 388bb19f3d4c11209f64c4c388452e6096a45174ab7225e252e6991980d56133

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/phase1-core-generation/proposal.md

- Source: openspec/changes/phase1-core-generation/proposal.md
- Lines: 1-33
- SHA256: 4762914ec2b7095b8c673813b2c10c947a99c341d4de2ea08039d21ecf6e38ff

```md
## Why

The Phase 1 MVP core scaffold (archived as `mvp-core-skeleton`) established the project skeleton — package structure, runtime types, transport splitting, and test harness — but left the actual code generation logic as TODO placeholders. Without these core capabilities, the plugin cannot generate functional Dart client code from proto definitions. This change fills that gap to deliver a working Phase 1 code generator.

## What Changes

- **google.api.http custom option extraction**: Implement `ExtensionRegistry` registration and `MethodOptions` re-parse to read `google.api.http` annotations (field 72295728) instead of silently dropping them as unknown fields
- **HTTP mapping engine**: Implement path parameter interpolation (`{field}`), query parameter flattening (non-path, non-body fields), and body mapping (`body: "*"`, `body: "field"`, no body)
- **Service facade generation**: Replace the TODO stub with real code generation using `code_builder` AST construction, producing complete `UnifiedService` classes with proper method signatures, HTTP transport calls, and error mapping
- **Transport base implementations**: Implement `HttpTransport` (using dio) and `GrpcTransport` (delegating to `*.pbgrpc.dart`) with unary call support
- **Server streaming support**: Add `serverStream<T>()` to the `Transport` abstract class and both implementations
- **ApiSdk entry generation**: Generate the `ApiSdk` unified entry class that wires up all service clients
- **Test coverage**: Replace placeholder tests with real verification — golden tests with full proto→Dart comparison, HTTP mapping unit tests, ExtensionRegistry extraction tests

## Capabilities

### New Capabilities
- `http-code-generation`: HTTP mapping engine (path interpolation, query flattening, body mapping) + service facade code generation via code_builder
- `grpc-code-generation`: gRPC transport delegation + service facade generation wrapping `*.pbgrpc.dart`
- `google-api-http-extraction`: ExtensionRegistry-based reading of `google.api.http` custom options from MethodOptions
- `transport-implementation`: HttpTransport (dio) and GrpcTransport base implementations with unary + server streaming
- `sdk-entry-generation`: ApiSdk unified entry class generation

### Modified Capabilities
- `unary-service-generation`: Current spec only covers facade structure; this change adds the actual code generation implementation (path binding, query flattening requirements become implemented, not just scaffolded)
- `golden-test-harness`: Current spec covers fixture support structure; this change adds real golden comparison tests with full proto→Dart output

## Impact

- **Files modified**: `lib/src/generator.dart`, `lib/src/parser/extension_registry.dart`, `lib/src/parser/descriptor_parser.dart`, `lib/src/runtime/transport.dart`, `lib/src/runtime/transport_native.dart`, `lib/src/runtime/transport_web.dart`
- **Files added**: `lib/src/builder/` (code_builder AST builders), `lib/src/generators/` (HttpGenerator, GrpcGenerator, FacadeGenerator, SdkGenerator), `test/golden/goldens/` (golden output files)
- **Dependencies**: `code_builder` (already in pubspec.yaml, currently unused), `dio` (already in pubspec.yaml)
- **No breaking changes**: All changes fill existing placeholders; no public API changes
```

## openspec/changes/phase1-core-generation/design.md

- Source: openspec/changes/phase1-core-generation/design.md
- Lines: 1-161
- SHA256: 76c76eb35da29192e791ce9bdb8af3f2d2d6a6f2e388e62b575220306a260352

[TRUNCATED]

```md
# Phase 1 Core Generation — Design Document

## Architecture Overview

```
proto → protoc → CodeGeneratorRequest
                          │
                          ▼
              ┌───────────────────────┐
              │   DescriptorParser    │
              │  (traverse + extract) │
              └───────────┬───────────┘
                          │ ServiceModel / MethodModel / HttpRuleModel
                          ▼
              ┌───────────────────────┐
              │     Generators        │
              │  ┌─────────────────┐  │
              │  │ HttpGenerator   │  │  ← google.api.http transcoding
              │  │ GrpcGenerator   │  │  ← wrap *.pbgrpc.dart
              │  │ FacadeGenerator │  │  ← unified service interface
              │  │ SdkGenerator    │  │  ← ApiSdk entry point
              │  └─────────────────┘  │
              └───────────┬───────────┘
                          │ code_builder AST
                          ▼
              ┌───────────────────────┐
              │    DartFormatter      │
              │  (in-process format)  │
              └───────────┬───────────┘
                          │
                          ▼
              CodeGeneratorResponse → stdout
```

## Key Design Decisions

### 1. ExtensionRegistry: Vendored google/api protos

Rather than depending on the full `googleapis` package (which is massive and not Dart-optimized), we **vendor** the minimal generated descriptor files:
- `lib/src/parser/google/api/http.pb.dart` — HttpRule message
- `lib/src/parser/google/api/annotations.pb.dart` — Annotations extension (field 72295728)

These are generated once from the fixture protos and checked into the repo. The `createHttpExtensionRegistry()` function registers `Annotations.http` so `MethodOptions` re-parse can extract `HttpRule`.

### 2. HTTP Mapping Engine

The `HttpMapper` class handles three concerns:

| Concern | Logic |
|---------|-------|
| **Path interpolation** | Parse `{field}` and `{field=segments/*}` templates from HttpRule path; map to request message fields |
| **Query flattening** | Fields not bound to path or body become query params; nested messages use dot-notation (`a.b.c`) |
| **Body mapping** | `body: "*"` → entire request as JSON body; `body: "field"` → specific sub-field; no body for GET/DELETE |

Path template parsing uses a simple state machine (not regex) for correctness with nested braces.

### 3. Code Generation via code_builder

All generators use `package:code_builder` to construct Dart AST nodes, ensuring:
- Always syntactically correct output
- Proper import management via `DartEmitter.scoped()`
- No string-escaping issues

Generated structure per service:
```dart
// user_service.dart
import 'package:protobuf/protobuf.dart';
import 'package:dio/dio.dart';
import '../user.pb.dart';           // official message types
import '../user.pbgrpc.dart';       // official gRPC client (if grpc)

abstract class UserService {
  Future<User> getUser(GetUserRequest request);
  Future<User> createUser(CreateUserRequest request);
}

class UnifiedUserService implements UserService {
  final Transport _transport;
  // ... method implementations routing to HttpTransport or GrpcTransport
}
```

Full source: openspec/changes/phase1-core-generation/design.md

## openspec/changes/phase1-core-generation/tasks.md

- Source: openspec/changes/phase1-core-generation/tasks.md
- Lines: 1-50
- SHA256: 35201116928cd2fb7a785c2b347741c7191e09aa8263f1781840b69a8b3c1044

```md
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
```

## openspec/changes/phase1-core-generation/specs/golden-test-harness-delta/spec.md

- Source: openspec/changes/phase1-core-generation/specs/golden-test-harness-delta/spec.md
- Lines: 1-33
- SHA256: ae16fe788f5907aa58864384e178418f854ca2b8367fded1bdf09704cf823f6f

```md
# golden-test-harness Delta Specification

## Change Type: Modified

## Delta: Add real golden comparison tests (was scaffold-only)

The existing `golden-test-harness` spec defined the test structure but the tests were placeholders. This delta adds real golden comparison requirements.

### Added Requirements

#### Scenario: Full proto-to-Dart golden test
- **WHEN** the generator processes `test/fixtures/user.proto`
- **THEN** the generated output matches the golden file `test/goldens/user_service.dart.golden`

#### Scenario: Golden update mode
- **WHEN** the `--update-goldens` flag is passed to the test runner
- **THEN** golden files are regenerated from the current generator output

#### Scenario: ExtensionRegistry extraction test
- **WHEN** a proto method has `(google.api.http) = { get: "/v1/users/{id}" }`
- **THEN** the test confirms the `HttpRuleModel` is correctly extracted (not null, correct kind and path)

#### Scenario: HTTP mapping unit tests
- **WHEN** `HttpMapper.interpolatePath("/v1/users/{id}", request)` is called
- **THEN** the test verifies correct path interpolation output

#### Scenario: Query flattening unit tests
- **WHEN** `HttpMapper.flattenQuery(request, usedFields)` is called
- **THEN** the test verifies correct query parameter generation

#### Scenario: Body mapping unit tests
- **WHEN** `HttpMapper.resolveBody(request, bodyField)` is called
- **THEN** the test verifies correct body resolution for `*`, named field, and empty cases
```

## openspec/changes/phase1-core-generation/specs/google-api-http-extraction/spec.md

- Source: openspec/changes/phase1-core-generation/specs/google-api-http-extraction/spec.md
- Lines: 1-42
- SHA256: 34dc6b75a10c2febfc028adc49fbe6ecd1c3642adf0941218ef60200c143bfdb

```md
# google-api-http-extraction Specification

## Purpose
Extract `google.api.http` custom options from method descriptors using an `ExtensionRegistry`, so HTTP annotations are never silently dropped as unknown fields.

## Requirements

### Requirement: ExtensionRegistry registration

The system SHALL register the `Annotations.http` extension (field 72295728 on `MethodOptions`) in the `ExtensionRegistry` used during descriptor parsing.

#### Scenario: Registry contains http extension
- **WHEN** `createHttpExtensionRegistry()` is called
- **THEN** the returned registry contains the `Annotations.http` extension field

#### Scenario: Vendored descriptor files
- **WHEN** the generator parses method options
- **THEN** it uses vendored `google/api/http.pb.dart` and `google/api/annotations.pb.dart` for extension registration

### Requirement: MethodOptions re-parse

The system SHALL re-parse `MethodDescriptorProto.options` bytes through `mergeFromBuffer(bytes, registry)` to extract custom options.

#### Scenario: HttpRule extracted from method options
- **WHEN** a method has `(google.api.http) = { get: "/v1/users/{id}" }`
- **THEN** the parser produces an `HttpRuleModel` with `kind: "get"` and `path: "/v1/users/{id}"`

#### Scenario: Method without annotation
- **WHEN** a method has no `google.api.http` annotation
- **THEN** the parser returns `null` for `HttpRuleModel` (not an error)

### Requirement: Full HttpRule mapping

The system SHALL map all `HttpRule` fields to `HttpRuleModel`: `kind`, `path`, `body`, `response_body`, and `additional_bindings`.

#### Scenario: Additional bindings preserved
- **WHEN** a method declares multiple HTTP bindings
- **THEN** `HttpRuleModel.additionalBindings` contains each secondary binding

#### Scenario: Body mapping captured
- **WHEN** `body: "*"` or `body: "field_name"` is set
- **THEN** `HttpRuleModel.body` contains the exact string value
```

## openspec/changes/phase1-core-generation/specs/grpc-code-generation/spec.md

- Source: openspec/changes/phase1-core-generation/specs/grpc-code-generation/spec.md
- Lines: 1-38
- SHA256: d3c25708e8cd6bbd4b1b28cf5c2418c90214d1505fb82d26d03b6f1fe36c1795

```md
# grpc-code-generation Specification

## Purpose
Generate Dart service facades that delegate to official `protoc-gen-dart` gRPC client stubs (`*.pbgrpc.dart`), providing protocol-transparent RPC calls.

## Requirements

### Requirement: gRPC transport delegation

The system SHALL generate `GrpcTransport` that delegates to the official `*ServiceClient` generated by `protoc-gen-dart`.

#### Scenario: Unary gRPC call
- **WHEN** a method is configured for gRPC transport
- **THEN** the generated code calls `UserServiceClient.getUser(request, options: options)`

#### Scenario: gRPC metadata passthrough
- **WHEN** `RpcCallOptions.headers` is set
- **THEN** the generated code passes headers as gRPC `CallOptions` metadata

### Requirement: gRPC error mapping

The system SHALL map `GrpcError` to `ApiException` subclasses using the gRPC canonical code directly.

#### Scenario: gRPC error code mapped
- **WHEN** a gRPC call fails with `GrpcError.notFound`
- **THEN** the generated code throws `NotFoundException`

#### Scenario: gRPC timeout
- **WHEN** a gRPC call exceeds the deadline
- **THEN** the generated code throws `RpcTimeoutException`

### Requirement: Server streaming gRPC

The system SHALL support server streaming via gRPC native `ResponseStream<T>`.

#### Scenario: Server streaming gRPC call
- **WHEN** a method has `returns (stream OutputType)` and gRPC transport is active
- **THEN** the generated code returns `ResponseStream<OutputType>` from the `*ServiceClient`
```

## openspec/changes/phase1-core-generation/specs/http-code-generation/spec.md

- Source: openspec/changes/phase1-core-generation/specs/http-code-generation/spec.md
- Lines: 1-107
- SHA256: a80c48551297e4f66ef1a687f107524046670918317965182863295a1f2b40b8

[TRUNCATED]

```md
# http-code-generation Specification

## Purpose
Generate complete Dart service facades with HTTP transport calls, using `code_builder` AST construction for syntactically correct output.

## Requirements

### Requirement: Path parameter interpolation

The system SHALL interpolate `{field}` path placeholders with Dart expression accessors from the request message.

#### Scenario: Simple path field
- **WHEN** a path template is `/v1/users/{id}` and the request has field `id`
- **THEN** the generated code uses string interpolation `"/v1/users/${request.id}"`

#### Scenario: Nested path field
- **WHEN** a path template is `/v1/users/{user.id}` and the request has nested field `user.id`
- **THEN** the generated code accesses `request.user.id`

#### Scenario: Segment wildcard
- **WHEN** a path template contains `{name=segments/*}`
- **THEN** the generated code uses the field `name` with segment expansion

### Requirement: Query parameter flattening

The system SHALL emit non-path, non-body fields as URL query parameters.

#### Scenario: Simple query params
- **WHEN** a request has fields `page` and `limit` not used in path or body
- **THEN** the generated code adds `?page=${request.page}&limit=${request.limit}`

#### Scenario: Nested message query params
- **WHEN** a request has nested message field `filter.name`
- **THEN** the generated code uses dot-notation `filter.name=${request.filter.name}`

#### Scenario: No query params for GET with body:*
- **WHEN** `body: "*"` is set and all fields are consumed by body
- **THEN** no query parameters are generated

### Requirement: Body mapping

The system SHALL map request body according to the `body` field in HttpRule.

#### Scenario: Full body
- **WHEN** `body: "*"` is set
- **THEN** the generated code serializes the entire request message as JSON body

#### Scenario: Field body
- **WHEN** `body: "field_name"` is set
- **THEN** the generated code serializes only the specified sub-field as body

#### Scenario: No body
- **WHEN** the HTTP method is GET or DELETE with no body field
- **THEN** the generated code sends no request body

### Requirement: code_builder AST generation

The system SHALL use `package:code_builder` to construct all generated Dart code.

#### Scenario: Valid Dart output
- **WHEN** any service facade is generated
- **THEN** the output is syntactically valid Dart that passes `dart analyze`

#### Scenario: Proper imports
- **WHEN** a generated file references external types
- **THEN** the generated code includes correct `import` statements via `DartEmitter.scoped()`

### Requirement: Unary method signature

The system SHALL generate unary method signatures returning `Future<Response>`.

#### Scenario: Unary method generated
- **WHEN** a service method has unary input and output
- **THEN** the generated facade exposes `Future<OutputType> methodName(InputType request)`

### Requirement: Server streaming method signature

The system SHALL generate server streaming method signatures returning `Stream<Response>`.

#### Scenario: Server streaming method generated
```

Full source: openspec/changes/phase1-core-generation/specs/http-code-generation/spec.md

## openspec/changes/phase1-core-generation/specs/sdk-entry-generation/spec.md

- Source: openspec/changes/phase1-core-generation/specs/sdk-entry-generation/spec.md
- Lines: 1-42
- SHA256: f8877df399d6872cc06a3f05c84881d77657d73ec76015b6c58b38962ab673e5

```md
# sdk-entry-generation Specification

## Purpose
Generate the `ApiSdk` unified entry class that wires up all service clients with the configured transport, interceptors, and protocol selection.

## Requirements

### Requirement: ApiSdk class generation

The system SHALL generate an `ApiSdk` class as the single entry point for all generated services.

#### Scenario: ApiSdk with single service
- **WHEN** a proto file contains one service `UserService`
- **THEN** the generated `ApiSdk` exposes `userService` as a lazy-initialized property

#### Scenario: ApiSdk with multiple services
- **WHEN** a proto file contains multiple services
- **THEN** the generated `ApiSdk` exposes a property for each service

#### Scenario: ApiSdk constructor
- **WHEN** `ApiSdk` is constructed
- **THEN** it accepts `ClientOptions` and initializes the transport and interceptors

### Requirement: Protocol.auto routing

The generated `ApiSdk` SHALL implement the `Protocol.auto` selection rules.

#### Scenario: Web forces HTTP
- **WHEN** `Protocol.auto` is configured on Web
- **THEN** all service methods use HTTP transport

#### Scenario: Native prefers gRPC
- **WHEN** `Protocol.auto` is configured on Native with gRPC available
- **THEN** all service methods use gRPC transport

### Requirement: Interceptor chain

The generated `ApiSdk` SHALL support interceptor injection.

#### Scenario: Interceptor registered
- **WHEN** an interceptor is added via `ApiSdk.addInterceptor()`
- **THEN** all service calls pass through the interceptor chain before reaching the transport
```

## openspec/changes/phase1-core-generation/specs/transport-implementation/spec.md

- Source: openspec/changes/phase1-core-generation/specs/transport-implementation/spec.md
- Lines: 1-58
- SHA256: 47c334dac3eb98b738a7ff9a511d7ccf3e58c51f95570f67849a89e627a7a363

```md
# transport-implementation Specification

## Purpose
Provide concrete `Transport` implementations for HTTP (dio) and gRPC (delegating to `*.pbgrpc.dart`), with conditional import-based platform selection.

## Requirements

### Requirement: HttpTransport unary implementation

The system SHALL implement `HttpTransport.unaryCall` using `dio` for HTTP/JSON calls.

#### Scenario: Successful HTTP call
- **WHEN** `HttpTransport.unaryCall` is called with a valid endpoint and request
- **THEN** it sends an HTTP request with the correct method, path, query params, and body, and returns the deserialized response

#### Scenario: HTTP error response
- **WHEN` the server returns a non-2xx status code
- **THEN** `HttpTransport` maps it to the corresponding `ApiException` subclass via `grpcCodeToHttpStatus`

#### Scenario: DioException handling
- **WHEN** `dio` throws a `DioException` (network error, timeout, etc.)
- **THEN** `HttpTransport` catches it and throws the appropriate `ApiException`

### Requirement: GrpcTransport unary implementation

The system SHALL implement `GrpcTransport.unaryCall` by delegating to the generated `*ServiceClient`.

#### Scenario: Successful gRPC call
- **WHEN** `GrpcTransport.unaryCall` is called
- **THEN** it calls the corresponding method on the `*ServiceClient` and returns the response

#### Scenario: GrpcError handling
- **WHEN` the gRPC call fails with a `GrpcError`
- **THEN** `GrpcTransport` maps the gRPC code to `ApiException` and throws

### Requirement: Server streaming transport

The system SHALL implement `serverStream` on both transports.

#### Scenario: gRPC server streaming
- **WHEN** `GrpcTransport.serverStream` is called
- **THEN** it returns the native `ResponseStream<T>` from the `*ServiceClient`

#### Scenario: HTTP server streaming placeholder
- **WHEN** `HttpTransport.serverStream` is called
- **THEN** it throws `UnimplementedError` (SSE deferred to Phase 3)

### Requirement: Transport factory platform selection

The system SHALL use conditional imports to select the correct transport at compile time.

#### Scenario: Native platform
- **WHEN** compiled with `dart.library.io`
- **THEN** `createTransport` returns a transport supporting both HTTP and gRPC

#### Scenario: Web platform
- **WHEN** compiled with `dart.library.js_interop`
- **THEN** `createTransport` returns an HTTP-only transport
```

## openspec/changes/phase1-core-generation/specs/unary-service-generation-delta/spec.md

- Source: openspec/changes/phase1-core-generation/specs/unary-service-generation-delta/spec.md
- Lines: 1-30
- SHA256: 54ff128945bd4d4b29a18e37d0ec3b63986b0ef43aa69949b62d08db1af2cdea

```md
# unary-service-generation Delta Specification

## Change Type: Modified

## Delta: Implement actual code generation (was scaffold-only)

The existing `unary-service-generation` spec defined the facade structure but the implementation only produced a TODO stub. This delta adds the concrete code generation requirements.

### Added Requirements

#### Scenario: Generated method with HTTP call
- **WHEN** a unary method has a `google.api.http` annotation
- **THEN** the generated facade method makes an HTTP call with correct path, query params, and body

#### Scenario: Generated method with gRPC delegation
- **WHEN** a unary method has no `google.api.http` annotation
- **THEN** the generated facade method delegates to the `*ServiceClient` gRPC stub

#### Scenario: Generated method error handling
- **WHEN** a generated method catches a transport-level exception
- **THEN** it maps it to the corresponding `ApiException` subclass

#### Scenario: code_builder usage
- **WHEN** any service facade is generated
- **THEN** the code is constructed via `package:code_builder` AST nodes, not string concatenation

#### Scenario: gRPC fallback for unannotated methods
- **WHEN** a service has no `google.api.http` annotations on any method
- **THEN** the generated facade delegates all methods to the `*ServiceClient` gRPC stub
- **AND** the generated import includes `../user.pbgrpc.dart`
```

