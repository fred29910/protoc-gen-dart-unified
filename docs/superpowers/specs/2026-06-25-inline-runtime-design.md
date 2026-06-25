# Inline Runtime — Eliminate `protoc_gen_dart_unified` as a Prod Dependency

**Date:** 2026-06-25
**Status:** Draft

## Problem

Generated service `.dart` files import `package:protoc_gen_dart_unified/src/runtime/...`, forcing
every consuming Flutter/Dart project to add `protoc_gen_dart_unified` as a **production dependency**
(even though it's a code-generation tool that shouldn't ship with the app).

Dependencies leaked into the generated code:

| Import | Package Required |
|--------|-----------------|
| `package:protoc_gen_dart_unified/src/runtime/transport.dart` | `protoc_gen_dart_unified` |
| `package:protoc_gen_dart_unified/src/runtime/client_options.dart` | `protoc_gen_dart_unified` |
| `package:protoc_gen_dart_unified/src/runtime/transport_factory.dart` | `protoc_gen_dart_unified` |

## Solution

Inline all runtime types into the generated output as a **co-generated `unified_runtime.dart`**
file, placed alongside the service `.dart` files. Service files import it via a local relative
path instead of a `package:` URI.

The only external runtime dependency remaining is `dio` (HTTP client), which `HttpTransport`
depends on and which cannot be inlined.

### File Layout (post-generation)

```
protoc output dir/
├── unified_runtime.dart        ← NEW: all runtime types inlined
├── user_service.dart           ← CHANGED: import 'unified_runtime.dart';
├── user_service_mock.dart      ← same change
├── user_service_example_test.dart
├── product_service.dart        ← same change
└── ...
```

### What Goes Into `unified_runtime.dart`

| Category | Types | Origin File(s) |
|----------|-------|----------------|
| **Abstract Transport** | `Transport` | `transport.dart` |
| **HTTP Transport (Native)** | `HttpTransport` (with `dart:io` SSE) | `transport_native.dart` |
| **HTTP Transport (Web)** | `HttpTransport` (with `dart:html`/`dio`) | `transport_web.dart` |
| **Factory** | `createTransport()` with `kIsWeb` branching | `transport_factory.dart` |
| **Call Options** | `RpcCallOptions`, `RpcCancelToken` | `rpc_call_options.dart`, `rpc_cancel_token.dart` |
| **Client Config** | `ClientOptions`, `Protocol` | `client_options.dart`, `protocol.dart` |
| **Interceptor** | `RpcInterceptor` (abstract), `InterceptorContext`, `RetryInterceptor`, `TracingInterceptor`, `LoggingInterceptor`, `AuthInterceptor` | `*_interceptor.dart` |
| **Retry** | `RetryPolicy` | `retry_policy.dart` |
| **Exception Hierarchy** | `ApiException` + 16 subclasses (`CancelledException`, `InvalidArgumentException`, `NotFoundException`, `InternalServerException`, etc.) | `api_exception.dart` |
| **SSE** | `SseParser` | `sse_parser.dart` |
| **Util** | `withRetry`, `http_status_mapping` helpers | `with_retry.dart`, `http_status_mapping.dart` |

### External Imports Preserved in `unified_runtime.dart`

```dart
import 'package:dio/dio.dart';       // HttpTransport needs it — cannot inline
```

### Platform Handling (`kIsWeb`)

Instead of Dart conditional imports (`if (dart.library.io)` / `if (dart.library.js_interop)`),
`unified_runtime.dart` uses `import 'package:flutter/foundation.dart' show kIsWeb` (or a simple
`bool.fromEnvironment('dart.library.io')` approach for non-Flutter Dart) to select the Transport
implementation at runtime:

```dart
Transport? createTransport(String endpoint, {dynamic grpcClient, List<RpcInterceptor> interceptors = const []}) {
  // Use dart:io-based implementation on native; dio+dart:html on web
  if (kIsWeb) {
    return _createWebTransport(endpoint, interceptors: interceptors);
  }
  return _createNativeTransport(endpoint, interceptors: interceptors);
}
```

Both `_createWebTransport` and `_createNativeTransport` are defined in the same file,
each wrapped in conditional sections.

### Changes to `CodeGenerator` (`lib/src/generator.dart`)

- After processing all services, emit a single `unified_runtime.dart` file via
  `CodeGeneratorResponse_File`.
- Only emit it once per `CodeGeneratorRequest`, NOT per service.

```dart
// Pseudo-code
final runtimeContent = _buildRuntimeContent();
files.add(CodeGeneratorResponse_File(
  name: 'unified_runtime.dart',
  content: runtimeContent,
));
```

### Changes to `ServiceGenerator` (`lib/src/generators/service_generator.dart`)

- Replace `_buildDirectives()` to import `'unified_runtime.dart'` (relative) instead of
  `package:protoc_gen_dart_unified/src/runtime/...`.
- Mock and example test generators get the same import change.

```dart
// Before
Directive.import('package:protoc_gen_dart_unified/src/runtime/transport.dart');

// After
Directive.import('unified_runtime.dart');
```

### New `RuntimeInlineGenerator` (`lib/src/generators/runtime_inline_generator.dart`)

A new generator that reads the current runtime source files and assembles them into a
single `unified_runtime.dart` string. Can either:

1. **Template-based**: Pre-composed string templates of each class (simpler, no runtime AST)
2. **code_builder-based**: Rebuild each class using `code_builder` (consistent with rest of project)

Option 1 is preferred for simplicity — the runtime types are stable and unlikely to change
frequently.

### Impact on User Projects

**Before:**
```yaml
dependencies:
  protoc_gen_dart_unified: ^0.1.0   # entire codegen tool as prod dep
  protobuf: ^6.0.0
  dio: ^5.9.0                       # transitive through protoc_gen_dart_unified
  grpc: ^5.1.0                      # transitive through protoc_gen_dart_unified
```

**After:**
```yaml
dependencies:
  dio: ^5.9.0                       # only explicit prod dep from our runtime
  protobuf: ^6.0.0                  # needed by proto-generated code anyway
  # grpc: only if using gRPC transport
```

### Backward Compatibility

- **Existing generated files**: Must be regenerated with the new plugin version.
- **Plugin parameters**: No new parameters required; the inline behavior is the default.
- **Current project tests**: Golden tests and integration tests will need their expected
  output updated to reflect the new import paths and the presence of `unified_runtime.dart`.

### Spec Self-Review

- **Placeholders**: None — all runtime source locations are known.
- **Internal consistency**: Every type referenced by generated code will be inlined into
  `unified_runtime.dart`; no dangling imports.
- **Scope**: Focused on a single concern (inlining). No scope creep.
- **Ambiguity**: The `kIsWeb` detection should handle both Flutter and pure-Dart contexts.
  Pure Dart can use `bool.fromEnvironment('dart.library.io')` as a fallback.
