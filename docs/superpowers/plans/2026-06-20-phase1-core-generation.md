# Phase 1 Core Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the core code generation logic for protoc-gen-dart-unified — ExtensionRegistry-based google.api.http extraction, HTTP mapping engine (path/query/body), code_builder-based service facade generation, transport implementations, and golden tests.

**Architecture:** DescriptorParser traverses FileDescriptorProto and extracts HttpRule via ExtensionRegistry re-parse. HttpMapper handles path interpolation, query flattening, and body mapping. Four generators (Http/Grpc/Facade/Sdk) use code_builder AST to produce a single `<service>_service.dart` file per service. Transport implementations provide HTTP (dio) and gRPC (delegate to *ServiceClient) backends with conditional import splitting.

**Tech Stack:** Dart SDK >=3.10.0, protoc_plugin 25.0.0, protobuf 6.0.0, code_builder 4.11.1, dart_style 3.1.9, dio 5.9.2, grpc 5.1.0, test 1.31.1

## Global Constraints

- All generated code must use `package:code_builder` AST construction (no string concatenation for code generation)
- All generated code must pass `dart analyze` with zero errors
- All generated code must be formatted via `DartFormatter(languageVersion: Version(3, 10, 0))`
- Single file per service: `<service>_service.dart` contains abstract class + UnifiedServiceImpl + ApiSdk
- Per-service transport selection: if any method has `google.api.http` → HttpGenerator; otherwise → GrpcGenerator
- Server streaming: gRPC delegates to native `ResponseStream`, HTTP throws `UnimplementedError`
- TDD mode: write failing test first, then implement, then verify pass
- Each task ends with a commit

---

### Task 1: ExtensionRegistry + google.api.http Extraction

**Files:**
- Create: `lib/src/parser/google/api/http.pb.dart`
- Create: `lib/src/parser/google/api/annotations.pb.dart`
- Modify: `lib/src/parser/extension_registry.dart`
- Modify: `lib/src/parser/descriptor_parser.dart`
- Create: `lib/src/model/field_model.dart`
- Create: `lib/src/model/message_model.dart`
- Modify: `lib/src/model/method_model.dart`
- Modify: `lib/src/model/service_model.dart`
- Test: `test/parser/extension_registry_test.dart`

**Interfaces:**
- Produces: `FieldModel`, `MessageModel`, updated `MethodModel` (with `isServerStreaming`, `isClientStreaming`, `inputFields`), updated `ServiceModel` (with `messages`)
- Produces: `createHttpExtensionRegistry()` that registers `Annotations.http`
- Produces: `DescriptorParser.parse()` that returns `List<ServiceModel>` with fully resolved messages and HttpRule

- [x] **Step 1: Write failing test for ExtensionRegistry extraction**

Create `test/parser/extension_registry_test.dart` with a test that builds a `CodeGeneratorRequest` containing a method with `google.api.http` annotation and verifies the annotation is extracted (not null). This test will fail because `createHttpExtensionRegistry()` returns an empty registry.

Expected: FAIL with "expected HttpRuleModel but got null"

- [x] **Step 2: Run test to verify it fails**

Run: `dart test test/parser/extension_registry_test.dart -v`
Expected: FAIL

- [x] **Step 3: Vendor google/api protos**

Generate `http.pb.dart` and `annotations.pb.dart` from the fixture protos at `test/fixtures/google/api/http.proto`. Place them in `lib/src/parser/google/api/`. These provide the `HttpRule` message class and `Annotations.http` extension (field 72295728 on `MethodOptions`).

- [x] **Step 4: Implement `createHttpExtensionRegistry()`**

Modify `lib/src/parser/extension_registry.dart` to register `Annotations.http`:
```dart
import 'google/api/annotations.pb.dart';
import 'google/api/http.pb.dart';
import 'package:protobuf/protobuf.dart';

ExtensionRegistry createHttpExtensionRegistry() {
  final registry = ExtensionRegistry();
  registry.add(Annotations.http);
  return registry;
}
```

- [x] **Step 5: Create `FieldModel`**

Create `lib/src/model/field_model.dart`:
```dart
class FieldModel {
  final String name;
  final String type;
  final bool isRepeated;
  final bool isMap;
  final String? messageType; // for message-type fields, the fully-qualified name

  const FieldModel({
    required this.name,
    required this.type,
    this.isRepeated = false,
    this.isMap = false,
    this.messageType,
  });
}
```

- [x] **Step 6: Create `MessageModel`**

Create `lib/src/model/message_model.dart`:
```dart
import 'field_model.dart';

class MessageModel {
  final String name;
  final String fullName; // fully-qualified, e.g. ".user.v1.GetUserRequest"
  final List<FieldModel> fields;

  const MessageModel({
    required this.name,
    required this.fullName,
    required this.fields,
  });
}
```

- [x] **Step 7: Update `MethodModel`**

Modify `lib/src/model/method_model.dart` to add streaming flags and input fields:
```dart
import 'package:protobuf/protobuf.dart';
import 'http_rule_model.dart';

class MethodModel {
  final String name;
  final String inputType;
  final String outputType;
  final HttpRuleModel? httpRule;
  final bool isServerStreaming;
  final bool isClientStreaming;

  const MethodModel({
    required this.name,
    required this.inputType,
    required this.outputType,
    this.httpRule,
    this.isServerStreaming = false,
    this.isClientStreaming = false,
  });
}
```

- [x] **Step 8: Update `ServiceModel`**

Modify `lib/src/model/service_model.dart` to include messages:
```dart
import 'method_model.dart';
import 'message_model.dart';

class ServiceModel {
  final String name;
  final List<MethodModel> methods;
  final List<MessageModel> messages;

  const ServiceModel({
    required this.name,
    required this.methods,
    this.messages = const [],
  });
}
```

- [x] **Step 9: Implement `DescriptorParser._extractHttpRule()`**

Modify `lib/src/parser/descriptor_parser.dart`:
- Add `_extractHttpRule()` that re-parses `MethodDescriptorProto.options` bytes via `mergeFromBuffer(bytes, registry)` and calls `getExtension(Annotations.http)`
- Add `_mapHttpRule()` that converts `HttpRule` to `HttpRuleModel` (handling oneof pattern field for get/post/put/patch/delete/custom)
- Add `_parseMessages()` that builds `MessageModel` list from `DescriptorProto`
- Update `parse()` to detect streaming (`method.serverStreaming`, `method.clientStreaming`) and build messages

- [x] **Step 10: Run test to verify it passes**

Run: `dart test test/parser/extension_registry_test.dart -v`
Expected: PASS

- [x] **Step 11: Run all tests to verify no regressions**

Run: `dart test -v`
Expected: All existing tests PASS

- [x] **Step 12: Commit**

```bash
git add lib/src/parser/google/api/ lib/src/parser/extension_registry.dart lib/src/parser/descriptor_parser.dart lib/src/model/field_model.dart lib/src/model/message_model.dart lib/src/model/method_model.dart lib/src/model/service_model.dart test/parser/extension_registry_test.dart
git commit -m "feat: implement ExtensionRegistry + google.api.http extraction with MessageModel parsing"
```

---

### Task 2: HTTP Mapping Engine

**Files:**
- Create: `lib/src/builder/http_mapper.dart`
- Create: `lib/src/builder/path_mapping.dart`
- Create: `lib/src/builder/query_field.dart`
- Create: `lib/src/builder/body_mapping.dart`
- Test: `test/builder/http_mapper_test.dart`

**Interfaces:**
- Consumes: `MessageModel`, `HttpRuleModel`
- Produces: `HttpMapper` class with `mapPath()`, `flattenQuery()`, `resolveBody()` static methods
- Produces: `PathMapping`, `QueryField`, `BodyMapping` value classes

- [x] **Step 1: Write failing tests for HttpMapper**

Create `test/builder/http_mapper_test.dart` with tests for:
- `HttpMapper.mapPath("/v1/users/{id}", fields)` → `PathMapping(literals: ["/v1/users/"], fields: ["id"])`
- `HttpMapper.mapPath("/v1/users/{user.id}", fields)` → nested field path
- `HttpMapper.mapPath("/files/{name=segments/*}", fields)` → segment wildcard
- `HttpMapper.flattenQuery(fields, {"id"}, "")` → query fields excluding path-bound `id`
- `HttpMapper.resolveBody(fields, "*")` → entire request body
- `HttpMapper.resolveBody(fields, "payload")` → field body
- `HttpMapper.resolveBody(fields, "")` → no body

Expected: FAIL with "HttpMapper not defined"

- [x] **Step 2: Run tests to verify they fail**

Run: `dart test test/builder/http_mapper_test.dart -v`
Expected: FAIL

- [x] **Step 3: Create value classes**

Create `lib/src/builder/path_mapping.dart`:
```dart
class PathMapping {
  final List<String> literalSegments;
  final List<String> pathFieldNames;
  const PathMapping({required this.literalSegments, required this.pathFieldNames});
}
```

Create `lib/src/builder/query_field.dart`:
```dart
class QueryField {
  final String name;
  final String dartAccessor;
  const QueryField({required this.name, required this.dartAccessor});
}
```

Create `lib/src/builder/body_mapping.dart`:
```dart
class BodyMapping {
  final String kind; // "all", "field", "none"
  final String? fieldName;
  const BodyMapping({required this.kind, this.fieldName});
}
```

- [x] **Step 4: Implement `HttpMapper`**

Create `lib/src/builder/http_mapper.dart` with:
- `mapPath()`: State-machine parser for `{field}` and `{field=segments/*}` templates. Iterates character-by-character, tracking `inBrace` state. Extracts field names and literal segments.
- `flattenQuery()`: Takes all message fields, removes path-bound fields and body field, returns `List<QueryField>` for remaining fields.
- `resolveBody()`: Returns `BodyMapping` based on `httpRule.body` value (`"*"` → all, non-empty → field, empty → none).

- [x] **Step 5: Run tests to verify they pass**

Run: `dart test test/builder/http_mapper_test.dart -v`
Expected: PASS

- [x] **Step 6: Run all tests to verify no regressions**

Run: `dart test -v`
Expected: All tests PASS

- [x] **Step 7: Commit**

```bash
git add lib/src/builder/ test/builder/
git commit -m "feat: implement HTTP mapping engine (path interpolation, query flattening, body mapping)"
```

---

### Task 3: Code Generation with code_builder

**Files:**
- Create: `lib/src/generators/http_generator.dart`
- Create: `lib/src/generators/grpc_generator.dart`
- Create: `lib/src/generators/facade_generator.dart`
- Create: `lib/src/generators/sdk_generator.dart`
- Modify: `lib/src/generator.dart`

**Interfaces:**
- Consumes: `ServiceModel`, `MessageModel`, `HttpRuleModel`
- Produces: `CodeGeneratorResponse_File` with complete generated Dart source
- Each generator produces `Spec` (code_builder AST) for its section

- [x] **Step 1: Write failing test for code generation**

Update `test/golden/golden_test.dart` to add a test that generates a service facade for a proto with `google.api.http` annotations and verifies the output contains expected class/method signatures.

Expected: FAIL with "class not found in output" or similar

- [x] **Step 2: Run test to verify it fails**

Run: `dart test test/golden/golden_test.dart -v`
Expected: FAIL

- [x] **Step 3: Create `FacadeGenerator`**

Create `lib/src/generators/facade_generator.dart`:
- Generates abstract service interface using `Interface((b) => b..name = serviceName)`
- Generates `UnifiedServiceImpl` class implementing the interface
- Each method delegates to `_transport.unaryCall(serviceName, methodName, request)`
- Uses `code_builder` `Method`, `Reference`, `Code` AST nodes

- [x] **Step 4: Create `HttpGenerator`**

Create `lib/src/generators/http_generator.dart`:
- Extends `FacadeGenerator` with HTTP-specific method bodies
- For each method with `HttpRule`, generates HTTP call using `HttpMapper` results
- Generates: `dio.get(path, queryParameters: query, data: body)` or `dio.post(...)` etc.
- Response deserialization: `OutputType.mergeFromProto3Json(response.data)`
- Error mapping: `try { ... } on DioException catch (e) { throw _mapDioError(e); }`

- [x] **Step 5: Create `GrpcGenerator`**

Create `lib/src/generators/grpc_generator.dart`:
- Extends `FacadeGenerator` with gRPC-specific method bodies
- For each method, generates delegation to `*ServiceClient`
- Generates: `UserServiceClient(_channel).getUser(request, options: _callOptions(options))`
- Error mapping: `try { ... } on GrpcError catch (e) { throw _mapGrpcError(e); }`

- [x] **Step 6: Create `SdkGenerator`**

Create `lib/src/generators/sdk_generator.dart`:
- Generates `ApiSdk` class with `ClientOptions` constructor
- Lazy-initialized service properties: `late final UserService userService = UnifiedUserService(_transport);`
- Transport initialization: `_transport = createTransport(options.endpoint);`

- [x] **Step 7: Refactor `CodeGenerator`**

Modify `lib/src/generator.dart`:
- Replace `_generateServiceFacade()` with generator coordination
- Per-service transport selection: `hasHttp → HttpGenerator`, `!hasHttp → GrpcGenerator`
- Wire up `FacadeGenerator` + transport generator + `SdkGenerator`
- Combine all AST sections, emit via `DartEmitter`, format via `formatDartSource()`

- [x] **Step 8: Run test to verify it passes**

Run: `dart test test/golden/golden_test.dart -v`
Expected: PASS

- [x] **Step 9: Run all tests to verify no regressions**

Run: `dart test -v`
Expected: All tests PASS

- [x] **Step 10: Commit**

```bash
git add lib/src/generators/ lib/src/generator.dart test/golden/
git commit -m "feat: implement code_builder-based service facade, HTTP/gRPC generators, and ApiSdk generation"
```

---

### Task 4: Transport Implementation

**Files:**
- Modify: `lib/src/runtime/transport.dart`
- Modify: `lib/src/runtime/transport_native.dart`
- Modify: `lib/src/runtime/transport_web.dart`
- Test: `test/runtime/transport_impl_test.dart`

**Interfaces:**
- Consumes: `Transport` abstract class (with `serverStream`)
- Produces: `HttpTransport` (dio-based), `GrpcTransport` (delegate to *ServiceClient)

- [x] **Step 1: Write failing tests for Transport implementations**

Create `test/runtime/transport_impl_test.dart` with tests for:
- `HttpTransport.unaryCall` makes correct HTTP request (mock dio)
- `HttpTransport.serverStream` throws `UnimplementedError`
- `GrpcTransport.unaryCall` delegates to *ServiceClient (mock)
- `GrpcTransport.serverStream` returns `ResponseStream`

Expected: FAIL with "HttpTransport not implemented"

- [x] **Step 2: Run tests to verify they fail**

Run: `dart test test/runtime/transport_impl_test.dart -v`
Expected: FAIL

- [x] **Step 3: Add `serverStream` to `Transport` abstract class**

Modify `lib/src/runtime/transport.dart`:
```dart
abstract class Transport {
  Future<T> unaryCall<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });

  Stream<T> serverStream<T>(
    String serviceName,
    String methodName,
    Object request, {
    RpcCallOptions? options,
  });
}
```

- [x] **Step 4: Implement `HttpTransport` for native**

Modify `lib/src/runtime/transport_native.dart`:
```dart
import 'package:dio/dio.dart';
import 'transport.dart';
import 'api_exception.dart';
import '../runtime/http_status_mapping.dart';

class HttpTransport implements Transport {
  final Dio _dio;
  HttpTransport(String endpoint) : _dio = Dio(BaseOptions(baseUrl: endpoint));

  @override
  Future<T> unaryCall<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options}) async {
    // 1. Build path from HttpRule (passed via options or looked up)
    // 2. dio.request(path, data: body, queryParameters: query)
    // 3. Deserialize response
    // 4. Map DioException → ApiException
    throw UnimplementedError('Requires HttpRule lookup — integrate with generator');
  }

  @override
  Stream<T> serverStream<T>(...) {
    throw UnimplementedError('SSE streaming deferred to Phase 3');
  }
}
```

Note: Full `HttpTransport` implementation requires the generated code to pass HttpRule data. The transport itself is a runtime component — the generator produces code that calls this transport. For now, implement the skeleton with correct method signatures and error mapping.

- [x] **Step 5: Implement `GrpcTransport` for native**

Modify `lib/src/runtime/transport_native.dart`:
```dart
import 'package:grpc/grpc.dart';
import 'transport.dart';
import 'api_exception.dart';

class GrpcTransport implements Transport {
  final Map<String, dynamic> _clients;
  GrpcTransport(this._clients);

  @override
  Future<T> unaryCall<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options}) {
    // Delegate to correct *ServiceClient based on serviceName
    throw UnimplementedError('Requires generated client registry');
  }

  @override
  Stream<T> serverStream<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options}) {
    // Delegate to native ResponseStream<T>
    throw UnimplementedError('Requires generated client registry');
  }
}
```

- [x] **Step 6: Implement `HttpTransport` for web**

Modify `lib/src/runtime/transport_web.dart`:
```dart
import 'package:dio/dio.dart';
import 'transport.dart';

Transport? createTransport(String endpoint) {
  return HttpTransport(endpoint); // web-compatible dio
}
```

- [x] **Step 7: Update transport stub**

Modify `lib/src/runtime/transport_stub.dart` to include `serverStream` signature.

- [x] **Step 8: Run tests to verify they pass**

Run: `dart test test/runtime/transport_impl_test.dart -v`
Expected: PASS

- [x] **Step 9: Run all tests to verify no regressions**

Run: `dart test -v`
Expected: All tests PASS

- [x] **Step 10: Commit**

```bash
git add lib/src/runtime/ test/runtime/transport_impl_test.dart
git commit -m "feat: implement Transport base classes (HttpTransport, GrpcTransport) with serverStream support"
```

---

### Task 5: Server Streaming Support

**Files:**
- Modify: `lib/src/parser/descriptor_parser.dart`
- Modify: `lib/src/model/method_model.dart`
- Modify: `lib/src/generators/facade_generator.dart`
- Modify: `lib/src/generators/http_generator.dart`

**Interfaces:**
- Consumes: `MethodDescriptorProto.clientStreaming`, `MethodDescriptorProto.serverStreaming`
- Produces: `MethodModel.isServerStreaming`, `MethodModel.isClientStreaming`
- Produces: Generated methods with `Stream<T>` return type for server streaming

- [x] **Step 1: Write failing test for streaming detection**

Update `test/parser/extension_registry_test.dart` to add a test: given a proto method with `returns (stream User)`, verify `MethodModel.isServerStreaming == true`.

Expected: FAIL with "expected true but got false"

- [x] **Step 2: Run test to verify it fails**

Run: `dart test test/parser/extension_registry_test.dart -v`
Expected: FAIL

- [x] **Step 3: Update `DescriptorParser` for streaming detection**

Modify `lib/src/parser/descriptor_parser.dart` in the `parse()` method:
```dart
final isServerStreaming = method.serverStreaming;
final isClientStreaming = method.clientStreaming;
```
Pass these to `MethodModel` constructor.

- [x] **Step 4: Update `FacadeGenerator` for streaming return types**

Modify `lib/src/generators/facade_generator.dart`:
- For server streaming methods: generate `Stream<OutputType> methodName(InputType request)`
- For unary methods: generate `Future<OutputType> methodName(InputType request)`

- [x] **Step 5: Update `HttpGenerator` for streaming stubs**

Modify `lib/src/generators/http_generator.dart`:
- For server streaming methods: generate body that throws `UnimplementedError('HTTP server streaming requires SSE, deferred to Phase 3')`

- [x] **Step 6: Run test to verify it passes**

Run: `dart test test/parser/extension_registry_test.dart -v`
Expected: PASS

- [x] **Step 7: Run all tests to verify no regressions**

Run: `dart test -v`
Expected: All tests PASS

- [x] **Step 8: Commit**

```bash
git add lib/src/parser/descriptor_parser.dart lib/src/generators/facade_generator.dart lib/src/generators/http_generator.dart
git commit -m "feat: add server streaming detection and Stream<T> return type generation"
```

---

### Task 6: Golden Tests + Integration Tests

**Files:**
- Create: `test/goldens/user_service.dart.golden`
- Modify: `test/golden/golden_test.dart`
- Test: `test/generator_integration_test.dart`

**Interfaces:**
- Consumes: `CodeGenerator`, fixture protos
- Produces: Golden file with expected generated output for `user.proto`
- Produces: Integration test verifying end-to-end generation

- [x] **Step 1: Write failing golden test**

Update `test/golden/golden_test.dart`:
- Build a `CodeGeneratorRequest` from `test/fixtures/user.proto` descriptors
- Run `CodeGenerator.generate(request)`
- Compare `response.file.first.content` against `test/goldens/user_service.dart.golden`
- Add `--update-goldens` flag support: when passed, write golden file instead of comparing

Expected: FAIL with "golden file not found" or content mismatch

- [x] **Step 2: Run test to verify it fails**

Run: `dart test test/golden/golden_test.dart -v`
Expected: FAIL

- [x] **Step 3: Generate golden file**

Run the generator with `--update-goldens` flag to create `test/goldens/user_service.dart.golden`. Manually verify the generated output contains:
- `abstract class UserService` with `getUser` and `createUser` methods
- `class UnifiedUserService implements UserService`
- `class ApiSdk` with `userService` property
- Correct HTTP path interpolation for `getUser`: `/v1/users/${request.id}`
- Correct body mapping for `createUser`: entire request as body

- [x] **Step 4: Write integration test**

Create `test/generator_integration_test.dart`:
- Test full round-trip: `CodeGeneratorRequest` → `CodeGenerator.generate()` → `CodeGeneratorResponse`
- Verify response contains valid Dart code (parse via `dart analyze` in-process or check structure)
- Verify `DartFormatter` idempotency on generated output

- [x] **Step 5: Run golden test to verify it passes**

Run: `dart test test/golden/golden_test.dart -v`
Expected: PASS

- [x] **Step 6: Run integration test to verify it passes**

Run: `dart test test/generator_integration_test.dart -v`
Expected: PASS

- [x] **Step 7: Run full test suite**

Run: `dart test -v`
Expected: All tests PASS

- [x] **Step 8: Run dart analyze on generated code**

Generate the `user_service.dart` output and run `dart analyze` on it to verify zero errors.

- [x] **Step 9: Commit**

```bash
git add test/goldens/ test/golden/golden_test.dart test/generator_integration_test.dart
git commit -m "feat: add golden tests and integration tests for end-to-end code generation"
```

---

### Task 7: Final Verification + Cleanup

**Files:**
- Modify: `openspec/changes/phase1-core-generation/tasks.md` (check all boxes)

- [x] **Step 1: Run full test suite**

Run: `dart test -v`
Expected: All tests PASS

- [x] **Step 2: Run dart analyze**

Run: `dart analyze`
Expected: 0 errors

- [x] **Step 3: Check all tasks are complete**

Verify all checkboxes in `openspec/changes/phase1-core-generation/tasks.md` are checked.

- [x] **Step 4: Final commit**

```bash
git add openspec/changes/phase1-core-generation/tasks.md
git commit -m "chore: complete phase1-core-generation — all tasks done"
```
