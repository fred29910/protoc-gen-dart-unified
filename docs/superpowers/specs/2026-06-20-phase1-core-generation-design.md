---
comet_change: phase1-core-generation
role: technical-design
canonical_spec: openspec
---

# Phase 1 Core Generation — Technical Design

## 1. Architecture

```
proto → protoc → CodeGeneratorRequest
                          │
                          ▼
              ┌───────────────────────┐
              │   DescriptorParser    │
              │  ┌─────────────────┐  │
              │  │ parse()         │  │  ← traverse FileDescriptorProto
              │  │ _extractHttpRule│  │  ← ExtensionRegistry re-parse
              │  │ _parseMessages  │  │  ← build MessageModel with fields
              │  └─────────────────┘  │
              └───────────┬───────────┘
                          │ List<ServiceModel>
                          ▼
              ┌───────────────────────┐
              │   CodeGenerator       │
              │  (coordinator)        │
              │  per-service:         │
              │   hasHttpAnnotation?  │
              │    ├─ yes → HttpGen   │
              │    └─ no  → GrpcGen   │
              └───────────┬───────────┘
                          │ code_builder AST
                          ▼
              ┌───────────────────────┐
              │    Generators         │
              │  HttpGenerator        │  ← HTTP transport calls
              │  GrpcGenerator        │  ← gRPC delegation
              │  FacadeGenerator      │  ← abstract + unified impl
              │  SdkGenerator         │  ← ApiSdk entry
              └───────────┬───────────┘
                          │ DartEmitter → String
                          ▼
              ┌───────────────────────┐
              │    DartFormatter      │
              │  (in-process)         │
              └───────────┬───────────┘
                          │
                          ▼
              CodeGeneratorResponse → stdout
```

## 2. ExtensionRegistry — Vendored Protos

### Approach

Pre-generate `google/api/http.pb.dart` and `google/api/annotations.pb.dart` using system `protoc` + official `protoc-gen-dart`, then vendor them into `lib/src/parser/google/api/`.

### File Layout

```
lib/src/parser/
├── google/api/
│   ├── http.pb.dart         ← vendored HttpRule message
│   └── annotations.pb.dart  ← vendored Annotations extension (field 72295728)
├── extension_registry.dart  ← createHttpExtensionRegistry()
└── descriptor_parser.dart   ← DescriptorParser
```

### createHttpExtensionRegistry()

```dart
ExtensionRegistry createHttpExtensionRegistry() {
  final registry = ExtensionRegistry();
  registry.add(annotations.http);  // field 72295728 on MethodOptions
  return registry;
}
```

### MethodOptions Re-parse

```dart
HttpRuleModel? _extractHttpRule(MethodDescriptorProto method, ExtensionRegistry registry) {
  if (!method.hasOptions()) return null;
  final options = MethodOptions();
  options.mergeFromBuffer(method.options.writeToBuffer(), registry);
  final httpRule = options.getExtension(Annotations.http);
  if (httpRule == null) return null;
  return _mapHttpRule(httpRule);
}
```

## 3. HTTP Mapping Engine

### HttpMapper Class

```dart
class HttpMapper {
  /// Parse path template, extract field names, build interpolation expression
  static PathMapping mapPath(String template, MessageModel request);
  
  /// Determine which fields become query params (not in path, not in body)
  static List<QueryField> flattenQuery(MessageModel request, Set<String> pathFields, String body);
  
  /// Resolve body: "*" → entire request, "field" → sub-field, "" → no body
  static BodyMapping resolveBody(MessageModel request, String bodyField);
}
```

### Path Template Parsing

State-machine parser (not regex) for `{field}` and `{field=segments/*}` templates:

```
/v1/users/{id}/posts/{post_id=posts/*}
  → literal segments: ["v1/users/", "/posts/"]
  → path fields: ["id", "post_id"]
  → Dart: "/v1/users/${request.id}/posts/${request.post_id}"
```

### Query Flattening

Fields not consumed by path or body become query parameters:
- Simple field `page` → `?page=${request.page}`
- Nested message `filter.name` → `?filter.name=${request.filter.name}`
- Repeated fields → repeated query params (`?tag=a&tag=b`)

### Body Mapping

| HttpRule.body | Behavior |
|---------------|----------|
| `"*"` | Entire request as JSON body |
| `"field_name"` | Only `request.fieldName` as JSON body |
| `""` (empty) | No body (GET/DELETE) |

## 4. Code Generation with code_builder

### Generator Coordination (per-service)

```dart
for (final service in services) {
  final hasHttp = service.methods.any((m) => m.httpRule != null);
  final generator = hasHttp
      ? HttpGenerator(service, messageModels)
      : GrpcGenerator(service, messageModels);
  final ast = generator.generate();  // returns Spec (code_builder AST)
  final source = _emit(ast);         // DartEmitter → String
  final formatted = formatDartSource(source);
  files.add(CodeGeneratorResponse_File(name: '${service.name.toLowerCase()}_service.dart', content: formatted));
}
```

### Generated File Structure

```dart
// user_service.dart (single file per service)
import 'package:protobuf/protobuf.dart';
import 'package:dio/dio.dart';
import '../user.pb.dart';

// ── Abstract Interface ──
abstract class UserService {
  Future<User> getUser(GetUserRequest request);
  Future<User> createUser(CreateUserRequest request);
}

// ── Unified Implementation ──
class UnifiedUserService implements UserService {
  final Transport _transport;
  UnifiedUserService(this._transport);
  
  @override
  Future<User> getUser(GetUserRequest request) async {
    // HTTP: GET /v1/users/{id} with query params
    // or gRPC: delegate to UserServiceClient
  }
}

// ── SDK Entry ──
class ApiSdk {
  final ClientOptions _options;
  late final UserService userService;
  ApiSdk(this._options) {
    final transport = createTransport(_options.endpoint);
    userService = UnifiedUserService(transport);
  }
}
```

### code_builder AST Construction

```dart
// Example: generating a method
Method((b) => b
  ..name = 'getUser'
  ..returns = refer('Future<User>')
  ..requiredParameters.add(Parameter((p) => p
    ..name = 'request'
    ..type = refer('GetUserRequest')))
  ..body = Code('/* generated body */'));
```

## 5. Transport Implementation

### HttpTransport (native + web)

```dart
class HttpTransport implements Transport {
  final Dio _dio;
  final String _endpoint;
  
  @override
  Future<T> unaryCall<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options}) {
    // 1. Look up HttpRule for serviceName+methodName
    // 2. Apply HttpMapper (path, query, body)
    // 3. dio.request(path, data: body, queryParameters: query, options: dioOptions)
    // 4. Deserialize response via mergeFromProto3Json()
    // 5. Map DioException → ApiException
  }
  
  @override
  Stream<T> serverStream<T>(...) {
    throw UnimplementedError('SSE streaming deferred to Phase 3');
  }
}
```

### GrpcTransport (native only)

```dart
class GrpcTransport implements Transport {
  final Map<Type, dynamic> _clients; // UserServiceClient, etc.
  
  @override
  Future<T> unaryCall<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options}) {
    // Route to correct *ServiceClient based on serviceName
    // Call method by name via dynamic dispatch
    // Map GrpcError → ApiException
  }
  
  @override
  Stream<T> serverStream<T>(...) {
    // Delegate to native ResponseStream<T>
  }
}
```

## 6. Server Streaming

### Transport Extension

```dart
abstract class Transport {
  Future<T> unaryCall<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options});
  Stream<T> serverStream<T>(String serviceName, String methodName, Object request, {RpcCallOptions? options});
}
```

### MethodModel Extension

```dart
class MethodModel {
  final String name;
  final String inputType;
  final String outputType;
  final HttpRuleModel? httpRule;
  final bool isServerStreaming;
  final bool isClientStreaming;
  final List<FieldModel> inputFields;  // from MessageModel
}
```

### Streaming Detection

```dart
// In DescriptorParser
final isServerStreaming = method.serverStreaming;
final isClientStreaming = method.clientStreaming;
```

## 7. Error Mapping

### DioException → ApiException

```dart
ApiException _mapDioException(DioException e) {
  final status = e.response?.statusCode ?? 0;
  final grpcCode = _httpStatusToGrpcCode(status);  // reverse mapping
  return _createApiException(grpcCode, e.message);
}
```

### GrpcError → ApiException

```dart
ApiException _mapGrpcError(GrpcError e) {
  return _createApiException(e.code, e.message);
}
```

## 8. Testing Strategy

### Unit Tests

| Test File | Coverage |
|-----------|----------|
| `test/builder/http_mapper_test.dart` | Path interpolation, query flattening, body mapping |
| `test/parser/descriptor_parser_test.dart` | Service/method/message traversal, streaming detection |
| `test/parser/extension_registry_test.dart` | ExtensionRegistry extraction with real proto bytes |

### Integration Tests

| Test File | Coverage |
|-----------|----------|
| `test/golden/golden_test.dart` | Full proto → Dart golden comparison |
| `test/generator_integration_test.dart` | CodeGenerator round-trip |

### Golden Files

```
test/goldens/
└── user_service.dart.golden  ← expected output for user.proto
```

## 9. File Changes Summary

### Modified Files

| File | Change |
|------|--------|
| `lib/src/generator.dart` | Wire up generators, per-service transport selection |
| `lib/src/parser/extension_registry.dart` | Register vendored Annotations.http |
| `lib/src/parser/descriptor_parser.dart` | MethodOptions re-parse, MessageModel field parsing, streaming detection |
| `lib/src/runtime/transport.dart` | Add `serverStream<T>()` to abstract class |
| `lib/src/runtime/transport_native.dart` | Implement HttpTransport + GrpcTransport |
| `lib/src/runtime/transport_web.dart` | Implement HttpTransport for web |
| `lib/src/model/method_model.dart` | Add `isServerStreaming`, `isClientStreaming`, `inputFields` |
| `lib/src/model/service_model.dart` | Add `messages` list |

### New Files

| File | Purpose |
|------|---------|
| `lib/src/parser/google/api/http.pb.dart` | Vendored HttpRule message |
| `lib/src/parser/google/api/annotations.pb.dart` | Vendored Annotations extension |
| `lib/src/builder/http_mapper.dart` | HTTP mapping engine |
| `lib/src/generators/http_generator.dart` | HTTP transport code generation |
| `lib/src/generators/grpc_generator.dart` | gRPC delegation code generation |
| `lib/src/generators/facade_generator.dart` | Abstract interface + unified impl |
| `lib/src/generators/sdk_generator.dart` | ApiSdk entry class |
| `lib/src/model/field_model.dart` | FieldModel for message fields |
| `lib/src/model/message_model.dart` | MessageModel with fields |
| `test/builder/http_mapper_test.dart` | HttpMapper unit tests |
| `test/goldens/user_service.dart.golden` | Golden output |
