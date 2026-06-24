# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

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
    │   ├── mock_service_generator.dart   # Mock client generator
    │   └── example_test_generator.dart   # Example test scaffold generator
    └── runtime/                          # Runtime transport layer: Transport, ClientOptions, RpcInterceptor, etc.
bin/
└── protoc_gen_dart_unified.dart          # Executable entry point
```

### Code Generation Flow

1. `bin/protoc_gen_dart_unified.dart` reads `CodeGeneratorRequest` from stdin
2. `DescriptorParser` parses proto descriptors, extracting services, methods, and `google.api.http` annotations via `ExtensionRegistry`
3. For each service, `ServiceGenerator` uses `code_builder` to construct Dart AST:
   - Abstract service interface
   - `Unified<ServiceImpl>` with interceptor chain
   - `ApiSdk` entry class
4. Output is formatted with `DartFormatter` and written to `CodeGeneratorResponse`

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
