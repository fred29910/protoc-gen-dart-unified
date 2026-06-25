# Inline Runtime — Eliminate `protoc_gen_dart_unified` as a Prod Dependency

**Date:** 2026-06-25
**Status:** Revised (2026-06-25, after code review)

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
| **HTTP Transport** | `HttpTransport` (unified: `dio` for both platforms) | `transport_native.dart` + `transport_web.dart` merged |
| **Factory** | `createTransport()` with platform detection | `transport_factory.dart` |
| **Call Options** | `RpcCallOptions`, `RpcCancelToken` | `rpc_call_options.dart`, `rpc_cancel_token.dart` |
| **Client Config** | `ClientOptions`, `Protocol` | `client_options.dart`, `protocol.dart` |
| **Interceptor** | `RpcInterceptor` (abstract), `InterceptorContext`, `RetryInterceptor`, `TracingInterceptor`, `LoggingInterceptor`, `AuthInterceptor` | `*_interceptor.dart` |
| **Retry** | `RetryPolicy` | `retry_policy.dart` |
| **Exception Hierarchy** | `ApiException` + 16 subclasses | `api_exception.dart` |
| **SSE** | `SseParser` | `sse_parser.dart` |
| **Util** | `withRetry`, `http_status_mapping` helpers | `with_retry.dart`, `http_status_mapping.dart` |

### What Is NOT Inlined

| Type | Reason |
|------|--------|
| `GrpcTransport` | Dead code — all methods throw `UnimplementedError`. Generated code uses `_grpcClient` directly, not `GrpcTransport`. Not inlined, can be removed from project. |

### External Imports Preserved in `unified_runtime.dart`

```dart
import 'package:dio/dio.dart';       // HttpTransport needs it — cannot inline
```

No `dart:io` or `dart:html` imports — all platform-specific code eliminated through refactoring.

### SSE Refactoring: Remove `dart:io` Dependency

The single-file approach requires **eliminating all platform-specific imports**. Currently
`transport_native.dart` uses `dart:io.HttpClient()` for SSE streaming. This prevents
compilation in a single file (Dart does not support conditional code blocks within a file).

**Solution:** Replace `dart:io.HttpClient` with `dio`'s `ResponseType.stream`:

```dart
// BEFORE (transport_native.dart — dart:io only)
import 'dart:io' as io;
// ...
io.HttpClient().openUrl(method, uri).then((req) {
  req.headers.set(...);
  return req.close().then((response) => SseParser.parse(response));
});

// AFTER (unified_runtime.dart — works cross-platform via dio)
final response = await _dio.get<ResponseBody>(
  path,
  options: Options(responseType: ResponseType.stream),
);
final stream = SseParser.parse(response.data!.stream);
```

`dio`'s `ResponseBody.stream` is `Stream<List<int>>` on all platforms, matching `SseParser`'s
input type. On web, SSE remains unimplemented (same as today); `dio` streaming is a net
improvement at worst, equivalent at best.

### Platform Detection

Use `bool.fromEnvironment` — works in all Dart environments (Flutter and pure Dart):

```dart
// Works in Flutter, pure Dart CLI, and server-side Dart
const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop', defaultValue: false);
// Alternative:
// const bool _kIsWeb = !bool.fromEnvironment('dart.library.io', defaultValue: true);
```

Do NOT import `package:flutter/foundation.dart` — the generated code must compile in
non-Flutter projects.

```dart
Transport? createTransport(String endpoint, {dynamic grpcClient, List<RpcInterceptor> interceptors = const []}) {
  if (_kIsWeb) {
    return HttpTransport(endpoint, interceptors: interceptors);  // SS: unimplemented
  }
  return HttpTransport(endpoint, interceptors: interceptors);    // SS: dio streaming
}
```

Both branches use the same `HttpTransport` class (single implementation using `dio` only).
The `_kIsWeb` branch exists solely for future divergence when web SSE matures.

### Changes to `CodeGenerator` (`lib/src/generator.dart`)

- After processing all services, emit a single `unified_runtime.dart` file via
  `CodeGeneratorResponse_File`.
- Only emit it once per `CodeGeneratorRequest`, NOT per service.

```dart
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

### `RuntimeInlineGenerator` (`lib/src/generators/runtime_inline_generator.dart`)

New generator that assembles `unified_runtime.dart` as a template string.

**Template drift mitigation** (review finding #4):
- Add a CI test: compile generated `unified_runtime.dart` in an isolated Dart project
  and run `dart analyze` to verify it compiles.
- A future improvement could add `tool/update_runtime_template.dart` to extract
  source from `lib/src/runtime/` files into the template.

### Version Marker (review finding #5)

The first line of `unified_runtime.dart` includes a version header:

```dart
// GENERATED_BY: protoc-gen-dart-unified@0.2.0 2026-06-25
// DO NOT EDIT: Runtime support types for the unified RPC SDK.
```

This helps debug stale generated code.

### Impact on User Projects

**Before:**
```yaml
dependencies:
  protoc_gen_dart_unified: ^0.1.0   # entire codegen tool as prod dep
  protobuf: ^6.0.0
  dio: ^5.9.0                       # transitive through protoc_gen_dart_unified
```

**After:**
```yaml
dependencies:
  dio: ^5.9.0                       # only explicit prod dep from our runtime
  protobuf: ^6.0.0                  # needed by proto-generated code anyway
```

**Migration Guide** (review finding #5):
1. Upgrade protoc-gen-dart-unified to the new version
2. Re-run `protoc` to regenerate all service files (unified_runtime.dart appears)
3. Remove `protoc_gen_dart_unified` from `dependencies:` (keep in `dev_dependencies:`
   if needed for build tooling)
4. Verify compilation: `dart analyze`

### Backward Compatibility

- **Existing generated files**: Must be regenerated. This is a one-time breaking change.
- **Plugin parameters**: No new parameters required; inline behavior is the default.
- **Current project tests**: Golden tests and integration tests will need expected output
   updated (`UPDATE_GOLDENS=1` workflow).

### Spec Self-Review (post-revision)

- **Placeholders**: None.
- **Internal consistency**: `GrpcTransport` explicitly excluded as dead code; SSE refactored
  to remove `dart:io`; single-file `unified_runtime.dart` now compiles on all platforms.
- **Scope**: Focused on inlining only. SSE refactoring is a prerequisite, not scope creep.
- **Ambiguity**: Platform detection uses `bool.fromEnvironment` — unambiguous, works everywhere.
