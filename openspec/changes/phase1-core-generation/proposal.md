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
