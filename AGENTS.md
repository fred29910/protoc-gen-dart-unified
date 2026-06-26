# AGENTS.md

**Generated:** 2026-06-26
**Commit:** `51fe1b7`
**Branch:** `main`

This file provides guidance to OpenCode when working with code in this repository.

## OVERVIEW

`protoc-gen-dart-unified` is a Dart/Flutter RPC SDK code generator plugin for `protoc` — generates unified client SDKs supporting HTTP (REST/JSON via `google.api.http`) and gRPC transports from a single `.proto`. Dart + `code_builder` + `protobuf`.

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Plugin entry | `bin/protoc_gen_dart_unified.dart` | Reads stdin, writes stdout |
| Code generation | `lib/src/generators/service_generator.dart` | 500 LOC, generates interface + impl + SDK |
| Inline runtime generation | `lib/src/generators/runtime_inline_generator.dart` | 837 LOC template, emits self-contained `unified_runtime.dart` |
| Mock generation | `lib/src/generators/mock_service_generator.dart` | Mock client for testing |
| Example test scaffold | `lib/src/generators/example_test_generator.dart` | Example test generator |
| Proto parsing | `lib/src/parser/descriptor_parser.dart` | FileDescriptorProto → ServiceModel |
| HTTP extension registry | `lib/src/parser/extension_registry.dart` | google.api.http custom option |
| Runtime transport | `lib/src/runtime/` | 19 files — transport, interceptors, SSE |
| HTTP mapping | `lib/src/builder/` | Path resolution, body mapping, query flattening |
| Data models | `lib/src/model/` | ServiceModel, MethodModel, HttpRuleModel, etc. |
| Integration test | `test/generator_integration_test.dart` | Programmatic CodeGeneratorRequest |
| Golden tests | `test/golden/golden_test.dart` | Expected output snapshots |
| Golden fixtures | `test/fixtures/` | Proto definitions for tests |

## Project Overview

`protoc-gen-dart-unified` is a Dart/Flutter RPC SDK code generator plugin for `protoc`. It generates unified client SDKs supporting both HTTP (REST/JSON via `google.api.http` annotations) and gRPC transports from a single `.proto` definition.

**Key design decisions:**
- HTTP/REST transport is custom-built (binds to `google.api.http` annotations for true RESTful paths)
- gRPC transport delegates to official `protoc-gen-dart` output (`*.pbgrpc.dart`)
- Transport selection at compile time via conditional imports (not runtime `kIsWeb` checks, to enable tree-shaking)
- Single-file generation per service by default

See `docs/design.md` for full architecture documentation.

## Commands

### Install dependencies
```bash
dart pub get
```

### Run all tests
```bash
dart test
```

### Run a single test file
```bash
dart test test/generator_integration_test.dart
```

### Run tests with coverage
```bash
dart test --coverage=coverage
```

### Static analysis
```bash
dart analyze --fatal-infos
```

### Format code
```bash
dart format .
```

### Check formatting (CI mode)
```bash
dart format --output=none --set-exit-if-changed .
```

### Compile the plugin binary
```bash
dart compile exe bin/protoc_gen_dart_unified.dart -o bin/protoc-gen-dart-unified
```

### Run the plugin via protoc
```bash
protoc --dart-unified_out=. --dart-unified_opt=mock=false path/to/service.proto
```

## Architecture

```
lib/
├── protoc_gen_dart_unified.dart          # Library entry point (exports generator.dart)
└── src/
    ├── generator.dart                    # CodeGenerator class: stdin → CodeGeneratorRequest → CodeGeneratorResponse
    ├── format_formatter.dart             # DartFormatter wrapper
    ├── parser/
    │   ├── descriptor_parser.dart        # Parses FileDescriptorProto → ServiceModel list
    │   ├── extension_registry.dart       # Registers google.api.http extension for custom option reading
    │   └── google/api/                   # Pre-generated protobuf descriptors for annotations
    ├── model/                            # Internal models: ServiceModel, MethodModel, HttpRuleModel, MessageModel, FieldModel
    ├── builder/                          # HTTP mapping logic: path resolution, body mapping, query flattening
    ├── generators/
    │   ├── service_generator.dart        # Main generator: abstract interface + Unified impl + ApiSdk
    │   ├── runtime_inline_generator.dart # Inline runtime generation, emits unified_runtime.dart
    │   ├── mock_service_generator.dart   # Mock client generator
    │   └── example_test_generator.dart   # Example test scaffold generator
    └── runtime/                          # Runtime transport layer: Transport, ClientOptions, RpcInterceptor, etc.
bin/
└── protoc_gen_dart_unified.dart          # Executable entry point
```

### Code Generation Flow

1. `bin/protoc_gen_dart_unified.dart` reads `CodeGeneratorRequest` from stdin
2. `DescriptorParser` parses proto descriptors, extracting services, methods, and `google.api.http` annotations via `ExtensionRegistry`
3. `RuntimeInlineGenerator` emits `unified_runtime.dart` — a self-contained runtime with transport, interceptors, SSE, auth, retry (only dep: `dio`)
4. For each service, `ServiceGenerator` generates:
   - Abstract service interface
   - `Unified<ServiceImpl>` implementation with interceptor chain
   - `ApiSdk` entry class
5. Optionally: `MockServiceGenerator` + `ExampleTestGenerator` produce `*_mock.dart` and `*_example_test.dart`
6. All outputs are formatted with `DartFormatter` and written to `CodeGeneratorResponse`

### Transport Selection Logic

- If any method has `google.api.http` annotation → HTTP transport (imports `transport_web.dart` via conditional import)
- Otherwise → gRPC transport (imports `transport_native.dart` which uses `*.pbgrpc.dart`)
- `Protocol.auto`: Web always uses HTTP; Native prefers gRPC if available

### Plugin Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `mock` | `true` | Generate mock + example test files |

Usage: `--dart-unified_opt=mock=false`

## Testing

- **Integration tests**: `test/generator_integration_test.dart` — constructs `CodeGeneratorRequest` programmatically and verifies generated output
- **Golden tests**: `test/goldens/` and `test/golden/` directories contain expected output files
- **Fixtures**: `test/fixtures/` contains test proto definitions

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- **ci.yml**: Test matrix (Dart stable + beta), formatting, analysis, coverage → Codecov
- **release.yml**: Manual version bump, CHANGELOG generation, git tag, GitHub Release, publish to pub.dev
- **dependency-review.yml**: PR dependency security review

## Lint Rules

Defined in `analysis_options.yaml`:
- `prefer_single_quotes`
- `prefer_const_constructors`
- `prefer_const_declarations`
- `avoid_print`
- `unnecessary_late`
- Strict casts, inference, and raw types enabled

## Interceptor Architecture

**Interceptor chain execution order:**
1. Tracing (if `tracingEnabled: true`)
2. User-provided interceptors
3. Retry (if `autoRetryEnabled: true` and `retryPolicy` is set)

**Key classes:**
- `RpcInterceptor` — Abstract interface for interceptors
- `InterceptorContext` — Context passed through the chain (serviceName, methodName, request, options)
- `Transport.executeWithInterceptors()` — Base method for interceptor chain execution
- `ClientOptions.buildInterceptorChain()` — Constructs the effective interceptor chain

**Important:** The generated `Unified<Service>` class manages its own interceptor chain (not `Transport`). The `Transport.executeWithInterceptors()` is called by `HttpTransport`/`GrpcTransport` with empty interceptors by default.

## Code Generation Details

**Generated file structure per service:**
- `{service_name}.dart` — Abstract interface + `Unified{ServiceName}` implementation + `ApiSdk` entry class
- `{service_name}_mock.dart` — Mock class for testing (when `mock=true`)
- `{service_name}_example_test.dart` — Example test scaffold (when `mock=true`)

**Naming conventions:**
- Proto `PascalCase` → Dart `snake_case` for file names
- Proto `PascalCase` → Dart `camelCase` for method names

## Golden Test Updates

To update golden files:
```bash
UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart
```

## Important Notes

- Generated code includes `// ignore_for_file: type=lint` to suppress lint rules in output
- `DartEmitter.scoped(useNullSafetySyntax: true)` is required for proper null safety syntax in generated code
- `GrpcTransport._client` field is reserved for future use (currently throws `UnimplementedError`)
- `ApiSdk` constructor body computes interceptor chain via `ClientOptions.buildInterceptorChain()` and passes it to the service implementation
