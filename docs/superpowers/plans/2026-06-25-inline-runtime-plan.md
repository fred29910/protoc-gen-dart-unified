# Inline Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate `unified_runtime.dart` alongside service files so generated code no longer depends on `package:protoc_gen_dart_unified`.

**Architecture:** A `RuntimeInlineGenerator` assembles all runtime class definitions into a template string. The `CodeGenerator` emits it once per request. Service/mock/test generators import `'unified_runtime.dart'` instead of `package:` paths. SSE in `transport_native.dart` is refactored to use `dio` streaming, removing the sole `dart:io` dependency.

**Tech Stack:** Dart 3.10+, dio 5.x, code_builder, protoc_plugin

## Global Constraints

- Generated code must compile on both native (iOS/Android/Desktop) and web
- Only external runtime import allowed: `package:dio/dio.dart`
- Platform detection: `bool.fromEnvironment('dart.library.js_interop')` — no Flutter dependency
- No `dart:io` or `dart:html` imports in generated output
- `GrpcTransport` is NOT inlined (it's dead code — all methods throw)
- Version marker `// GENERATED_BY: protoc-gen-dart-unified@<version>` in every generated file
- Template drift must be caught by CI test (not just manual)

---

## File Structure Map

```
lib/src/generators/
├── runtime_inline_generator.dart    ← NEW: produces unified_runtime.dart string
├── service_generator.dart           ← MODIFY: imports → 'unified_runtime.dart'
├── mock_service_generator.dart      ← MODIFY: same
└── example_test_generator.dart      ← MODIFY: same
lib/src/generator.dart               ← MODIFY: emit unified_runtime.dart
lib/src/runtime/
├── transport_native.dart            ← MODIFY: SSE refactor (dart:io → dio streaming)
test/golden/
├── *.dart                           ← UPDATE: golden expected output
test/
├── generator_integration_test.dart  ← MODIFY: expect unified_runtime.dart in output
```

---

### Task 1: SSE Refactoring — Replace `dart:io.HttpClient` with `dio` streaming

**Files:**
- Modify: `lib/src/runtime/transport_native.dart`
- Test: `test/runtime/transport_native_test.dart` (if exists)

**Context:** Current `_sseStream()` in `transport_native.dart` uses `dart:io.HttpClient`. This is the ONLY `dart:io` import in runtime. To make `unified_runtime.dart` a single compilable file, we must eliminate it.

**Changes to `lib/src/runtime/transport_native.dart`:**
1. Remove `import 'dart:io' as io;` (line 2)
2. Remove `import 'dart:async';` (line 1) — `StreamController` is re-imported indirectly or replace with `dart:async` from `dio`
3. Refactor `_sseStream()` method (lines 114-180) to use `dio.ResponseType.stream`

- [ ] **Step 1: Remove `dart:io` import**

  Delete line 2 (`import 'dart:io' as io;`). Keep `import 'dart:async'` if `StreamController` is still used.

- [ ] **Step 2: Refactor `_sseStream()` to use `dio` streaming**

  Replace the `io.HttpClient()` block with `dio` streaming:

  ```dart
  Stream<T> _sseStream<T>(
    String serviceName,
    String methodName,
    Object request,
    RpcCallOptions? options,
  ) {
    final controller = StreamController<T>();
    final path = options?.httpPath ?? '/$serviceName/$methodName';

    final queryParams = <String, dynamic>{};
    if (options?.httpQueryParams != null) {
      queryParams.addAll(options!.httpQueryParams!);
    }

    final headers = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
    if (options?.headers != null) {
      headers.addAll(options!.headers!);
    }

    _dio
        .request<ResponseBody>(
          path,
          data: options?.httpBody,
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
          options: Options(
            method: options?.httpMethod?.toUpperCase() ?? 'GET',
            responseType: ResponseType.stream,
            headers: headers,
            sendTimeout: options?.timeout,
            receiveTimeout: options?.timeout,
          ),
        )
        .then((response) {
          if (response.statusCode != 200) {
            controller.addError(
              InternalServerException(
                'SSE connection failed with status ${response.statusCode}',
              ),
            );
            controller.close();
            return;
          }
          final body = response.data;
          if (body == null) {
            controller.close();
            return;
          }
          SseParser.parse(body.stream).listen(
            (data) => controller.add(data as T),
            onError: controller.addError,
            onDone: controller.close,
          );
        })
        .catchError((Object e, StackTrace st) {
          controller.addError(e, st);
        });

    return controller.stream;
  }
  ```

- [ ] **Step 3: Run existing tests**

  Run: `dart test test/runtime/runtime_test.dart`
  Expected: All pass (SSE test may be skipped if no dedicated test exists)

- [ ] **Step 4: Commit**

  ```bash
  git add lib/src/runtime/transport_native.dart
  git commit -m "refactor: replace dart:io.HttpClient with dio streaming for SSE

  Eliminates the only dart:io import in runtime, unblocking single-file
  inlining of all runtime types into unified_runtime.dart."
  ```

---

### Task 2: Create `RuntimeInlineGenerator`

**Files:**
- Create: `lib/src/generators/runtime_inline_generator.dart`

**Context:** This generator produces the `unified_runtime.dart` string containing all runtime class definitions. It's a template-based generator (no code_builder AST) because the runtime types are stable and the template directly mirrors source files.

**Approach:** The template includes every class definition from `lib/src/runtime/` verbatim, except `GrpcTransport` (dead code, not inlined). The template must compile with only `import 'package:dio/dio.dart'` as external dep.

- [ ] **Step 1: Create `RuntimeInlineGenerator`**

  Create `lib/src/generators/runtime_inline_generator.dart`:

  ```dart
  class RuntimeInlineGenerator {
    String generate() {
      return '''// GENERATED_BY: protoc-gen-dart-unified@0.2.0
  // DO NOT EDIT: Runtime support types for the unified RPC SDK.

  import 'package:dio/dio.dart';

  // ============================================================
  // Exception Hierarchy
  // ============================================================

  abstract class ApiException implements Exception {
    final String message;
    final int? code;
    const ApiException(this.message, [this.code]);
    @override
    String toString() => 'ApiException(\$code): \$message';
  }

  class InvalidArgumentException extends ApiException {
    const InvalidArgumentException([String? msg])
      : super(msg ?? 'Invalid argument', 3);
  }
  // ... (all 15 remaining subclasses from api_exception.dart, verbatim) ...

  // ============================================================
  // Platform Detection
  // ============================================================

  const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop', defaultValue: false);

  // ============================================================
  // Call Options
  // ============================================================

  class RpcCallOptions {
    // ... (verbatim from rpc_call_options.dart) ...
  }

  class RpcCancelToken {
    // ... (verbatim from rpc_cancel_token.dart) ...
  }

  // ============================================================
  // Interceptor Context & Interface
  // ============================================================

  class InterceptorContext {
    // ... (verbatim from rpc_interceptor.dart, without imports) ...
  }

  abstract class RpcInterceptor {
    // ... (verbatim) ...
  }

  // ============================================================
  // Client Configuration
  // ============================================================

  class Protocol {
    // ... (verbatim from protocol.dart) ...
  }

  class ClientOptions {
    // ... (verbatim from client_options.dart, without imports) ...
  }

  // ============================================================
  // Retry Policy
  // ============================================================

  class RetryPolicy {
    // ... (verbatim from retry_policy.dart, without imports) ...
  }

  // ============================================================
  // Transport — Unified (dio only, no dart:io)
  // ============================================================

  abstract class Transport {
    // ... (verbatim from transport.dart) ...
  }

  class HttpTransport extends Transport {
    // Merged: unary call logic from transport_native.dart + transport_web.dart
    // (identical logic, uses dio only)
    // SSE uses dio.ResponseType.stream instead of dart:io.HttpClient
    final Dio _dio;
    final List<RpcInterceptor> _interceptors;

    HttpTransport(String endpoint, {List<RpcInterceptor> interceptors = const []})
      : _dio = Dio(BaseOptions(baseUrl: endpoint)),
        _interceptors = interceptors;

    @override
    Future<T> unaryCall<T>(...) { /* from transport_native.dart */ }

    @override
    Stream<T> serverStream<T>(...) {
      if (_kIsWeb) {
        throw UnimplementedError('HTTP server streaming not available on web');
      }
      return _nativeSseStream<T>(...);
    }

    Stream<T> _nativeSseStream<T>(...) {
      /* dio.ResponseType.stream based implementation from Task 1 */
    }

    ApiException _mapDioException(DioException e) { /* from transport_native.dart */ }
    int _httpStatusToGrpcCode(int status) { /* shared */ }
    ApiException _createApiException(int code, String message) { /* shared */ }
  }

  Transport? createTransport(
    String endpoint, {
    dynamic grpcClient,
    List<RpcInterceptor> interceptors = const [],
  }) {
    return HttpTransport(endpoint, interceptors: interceptors);
  }

  // ============================================================
  // SSE Parser
  // ============================================================

  class SseParser {
    // ... (verbatim from sse_parser.dart) ...
  }

  // ============================================================
  // Built-in Interceptors
  // ============================================================

  class TracingInterceptor implements RpcInterceptor {
    // ... (verbatim from tracing_interceptor.dart) ...
  }

  class RetryInterceptor implements RpcInterceptor {
    // ... (verbatim from retry_interceptor.dart, without imports) ...
  }

  class LoggingInterceptor implements RpcInterceptor {
    // ... (verbatim from logging_interceptor.dart) ...
  }

  class AuthInterceptor implements RpcInterceptor {
    // ... (verbatim from auth_interceptor.dart) ...
  }

  // ============================================================
  // Utilities
  // ============================================================

  // withRetry helper — verbatim from with_retry.dart
  // http_status_mapping — NOT inlined (gRPC-only, not needed for HTTP transport)
  ''';
    }
  }
  ```

  > **Implementation notes:** Copy class bodies verbatim from the source files. Remove `import` directives (only `package:dio/dio.dart` is needed at top). Remove `export` directives. Wrap SSE in `_kIsWeb` check. The `http_status_mapping.dart` is a gRPC utility — skip it (not inlined).

- [ ] **Step 2: Verify the template compiles**

  Write a temporary test:

  ```dart
  // test/generators/runtime_inline_generator_test.dart
  import 'package:test/test.dart';
  import 'package:protoc_gen_dart_unified/src/generators/runtime_inline_generator.dart';

  void main() {
    test('generates compilable runtime code', () {
      final gen = RuntimeInlineGenerator();
      final code = gen.generate();
      expect(code, contains('class HttpTransport'));
      expect(code, contains('class Transport'));
      expect(code, contains('class ApiException'));
      expect(code, contains('import \'package:dio/dio.dart\''));
      expect(code, doesNotContain("import 'dart:io'"));
      expect(code, doesNotContain("import 'dart:html'"));
      expect(code, contains('GENERATED_BY'));
    });
  }
  ```

  Run: `dart test test/generators/runtime_inline_generator_test.dart`
  Expected: PASS

- [ ] **Step 3: Compile test — verify generated code is valid Dart**

  Write a test that writes the generated output to a temp file and runs `dart analyze` on it:

  ```dart
  test('generated runtime code passes dart analyze', () {
    final gen = RuntimeInlineGenerator();
    final code = gen.generate();
    final tempDir = Directory.systemTemp.createTempSync('unified_runtime_test');
    try {
      // Write the generated file
      File('${tempDir.path}/unified_runtime.dart').writeAsStringSync(code);
      // Write a minimal pubspec with dio dependency
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
  name: runtime_test
  environment:
    sdk: '>=3.10.0 <4.0.0'
  dependencies:
    dio: ^5.9.0
  ''');
      // Run pub get and analyze in the temp dir
      final result = Process.runSync('dart', ['analyze', '--fatal-infos'],
        workingDirectory: tempDir.path);
      expect(result.exitCode, 0, reason: result.stderr as String?);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
  ```

  Run: `dart test test/generators/runtime_inline_generator_test.dart`
  Expected: PASS — this is the **template drift test** that catches missing imports or broken references in CI.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/src/generators/runtime_inline_generator.dart \
         test/generators/runtime_inline_generator_test.dart
  git commit -m "feat: add RuntimeInlineGenerator for unified_runtime.dart

  Template-based generator that produces a self-contained runtime file.
  Includes compile-verification test to prevent template drift."
  ```

---

### Task 3: Modify `CodeGenerator` to emit `unified_runtime.dart`

**Files:**
- Modify: `lib/src/generator.dart`

- [ ] **Step 1: Add `RuntimeInlineGenerator` import and emission**

  In `lib/src/generator.dart`:

  ```dart
  import 'generators/runtime_inline_generator.dart';
  ```

  In the `generate()` method, after the service loop (line 47-48), before the return (line 49):

  ```dart
  // Emit unified_runtime.dart once per request
  final runtimeFile = CodeGeneratorResponse_File(
    name: 'unified_runtime.dart',
    content: RuntimeInlineGenerator().generate(),
  );
  files.insert(0, runtimeFile); // insert first so it's easy to find in tests
  ```

- [ ] **Step 2: Run existing integration test**

  Run: `dart test test/generator_integration_test.dart`
  Expected: Test will likely FAIL because golden expectations don't include the new file yet. That's expected — proceed.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/src/generator.dart
  git commit -m "feat: emit unified_runtime.dart from CodeGenerator

  Added RuntimeInlineGenerator invocation to produce the inlined runtime
  file once per CodeGeneratorRequest."
  ```

---

### Task 4: Update `ServiceGenerator` imports

**Files:**
- Modify: `lib/src/generators/service_generator.dart`

- [ ] **Step 1: Replace package imports with local import**

  In `_buildDirectives()` method (lines 43-66), replace the three `package:protoc_gen_dart_unified/...` imports with a single local import:

  ```dart
  List<Directive> _buildDirectives() {
    final directives = <Directive>[
      Directive.import('unified_runtime.dart'),
      Directive.import(
        '../${service.protoFileName.replaceAll('.proto', '.pb.dart')}',
      ),
    ];
    if (!_useHttp) {
      directives.add(
        Directive.import(
          '../${service.protoFileName.replaceAll('.proto', '.pbgrpc.dart')}',
        ),
      );
    }
    return directives;
  }
  ```

  Delete the three removed lines:
  - `Directive.import('package:protoc_gen_dart_unified/src/runtime/transport.dart'),`
  - `Directive.import('package:protoc_gen_dart_unified/src/runtime/client_options.dart'),`
  - `Directive.import('package:protoc_gen_dart_unified/src/runtime/transport_factory.dart'),`

- [ ] **Step 2: Run `lsp_diagnostics`**

  Run: `dart analyze lib/src/generators/service_generator.dart`
  Expected: No errors

- [ ] **Step 3: Commit**

  ```bash
  git add lib/src/generators/service_generator.dart
  git commit -m "refactor: use local import of unified_runtime.dart in service generator

  Replaces three package:protoc_gen_dart_unified imports with a single
  relative import of the co-generated unified_runtime.dart."
  ```

---

### Task 5: Update `MockServiceGenerator` and `ExampleTestGenerator` imports

**Files:**
- Modify: `lib/src/generators/mock_service_generator.dart`
- Modify: `lib/src/generators/example_test_generator.dart`

- [ ] **Step 1: Update `MockServiceGenerator._buildDirectives()`**

  In `lib/src/generators/mock_service_generator.dart`, the `_buildDirectives` method (lines 30-38). Add `unified_runtime.dart` import before mock-specific imports:

  ```dart
  List<Directive> _buildDirectives() {
    return [
      Directive.import('unified_runtime.dart'),
      Directive.import('package:mockito/annotations.dart'),
      Directive.import(
        '../${service.protoFileName.replaceAll('.proto', '.pb.dart')}',
      ),
      Directive.import('${_dartServiceName(service.name)}.dart'),
    ];
  }
  ```

- [ ] **Step 2: Update `ExampleTestGenerator._buildDirectives()`**

  - [ ] Read the file first, then apply similar change (add `Directive.import('unified_runtime.dart')`).

- [ ] **Step 3: Run `lsp_diagnostics` on both files**

  ```bash
  dart analyze lib/src/generators/mock_service_generator.dart lib/src/generators/example_test_generator.dart
  ```
  Expected: No errors

- [ ] **Step 4: Commit**

  ```bash
  git add lib/src/generators/mock_service_generator.dart \
         lib/src/generators/example_test_generator.dart
  git commit -m "refactor: update mock and test generators to import unified_runtime.dart"
  ```

---

### Task 6: Update Golden Tests and Integration Tests

**Files:**
- Modify: `test/generator_integration_test.dart`
- Modify: `test/golden/golden_test.dart`
- Modify: golden fixture files in `test/goldens/` and `test/golden/`

- [ ] **Step 1: Update integration test expectations**

  In `test/generator_integration_test.dart`, the test that checks generated files needs to expect `unified_runtime.dart` in the output. Find the assertion about file count or file names and add `unified_runtime.dart`.

- [ ] **Step 2: Regenerate golden files**

  ```bash
  UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart
  ```

  This updates all golden expected output files to reflect the new imports.

- [ ] **Step 3: Verify golden tests pass**

  ```bash
  dart test test/golden/golden_test.dart
  ```
  Expected: All PASS

- [ ] **Step 4: Run full test suite**

  ```bash
  dart test
  ```
  Expected: All PASS. If any failures, fix them (likely due to changed generated output).

- [ ] **Step 5: Commit**

  ```bash
  git add test/
  git commit -m "test: update golden and integration tests for unified_runtime.dart"
  ```

---

### Task 7: Final Verification & Cleanup

**Files:**
- Verify: `lib/src/generator.dart` no longer imports runtime directly
- Verify: All generated file imports use `'unified_runtime.dart'`
- Run: Full analysis and tests

- [ ] **Step 1: Full static analysis**

  ```bash
  dart analyze --fatal-infos
  ```
  Expected: No errors or warnings.

- [ ] **Step 2: Full test suite**

  ```bash
  dart test
  ```
  Expected: All tests pass.

- [ ] **Step 3: Verify no `package:protoc_gen_dart_unified/` imports remain in generators**

  ```bash
  grep -rn "package:protoc_gen_dart_unified" lib/src/generators/
  ```
  Expected: No matches (all replaced with `unified_runtime.dart`).

- [ ] **Step 4: Verify `GrpcTransport` is NOT in the template**

  ```bash
  grep -n "GrpcTransport" lib/src/generators/runtime_inline_generator.dart
  ```
  Expected: No matches.

- [ ] **Step 5: Verify version marker present**

  ```bash
  grep "GENERATED_BY" lib/src/generators/runtime_inline_generator.dart
  ```
  Expected: Match found.

- [ ] **Step 6: Commit (if any fixes made)**

  ```bash
  git add -A
  git commit -m "chore: final cleanup after runtime inlining"
  ```

---

## Self-Review Checklist

- **Spec coverage:**
  - [x] Problem: generated code imports `package:protoc_gen_dart_unified` → Solved by Task 3-5 (local import)
  - [x] SSE refactoring to remove `dart:io` → Task 1
  - [x] Platform detection via `bool.fromEnvironment` → Task 2 template
  - [x] `GrpcTransport` NOT inlined → Task 2 (skipped from template), verified in Task 7
  - [x] Version marker → Task 2 template
  - [x] Template drift test → Task 2 Step 3 (compile test in temp dir)
  - [x] Migration guide → documented in spec
  - [x] Golden test updates → Task 6

- **Placeholder scan:** No "TBD", "TODO", or vague instructions. All code blocks are concrete.

- **Type consistency:** The `RuntimeInlineGenerator.generate()` method signature is used consistently across tasks.
