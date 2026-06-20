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

class ApiSdk {
  final ClientOptions _options;
  late final UserService userService;
  // ... constructor wires up all services
}
```

### 4. Transport Implementation

**HttpTransport** (native + web):
- Uses `dio` for HTTP calls
- JSON serialization via `toProto3Json()` / `mergeFromProto3Json()`
- Maps `DioException` → `ApiException` using the 17-code table

**GrpcTransport** (native only):
- Delegates to generated `*ServiceClient` from `*.pbgrpc.dart`
- Passes metadata via `CallOptions`
- Maps `GrpcError` → `ApiException` using gRPC code directly

### 5. Server Streaming

Added to `Transport` abstract class:
```dart
Stream<T> serverStream<T>(
  String serviceName,
  String methodName,
  Object request, {
  RpcCallOptions? options,
});
```

- gRPC: delegates to native `ResponseStream`
- HTTP: placeholder (Phase 3 SSE); throws `UnimplementedError` for now

## Data Flow

```
MethodDescriptorProto
        │
        ├── name, inputType, outputType → MethodModel
        │
        └── options bytes ──→ mergeFromBuffer(bytes, registry)
                                    │
                                    └── getExtension(Annotations.http)
                                              │
                                              └── HttpRule → HttpRuleModel
                                                                  │
                                                                  ▼
                                                    ┌─────────────────────┐
                                                    │ HttpMapper          │
                                                    │  • path template    │
                                                    │  • query fields     │
                                                    │  • body mapping     │
                                                    └─────────┬───────────┘
                                                              │
                                                              ▼
                                                    code_builder AST
                                                              │
                                                              ▼
                                                    DartFormatter
                                                              │
                                                              ▼
                                                    CodeGeneratorResponse.File
```

## Error Handling

- **Parse errors**: Caught at generator level → `CodeGeneratorResponse.error`
- **Missing annotations**: Methods without `google.api.http` still generate gRPC-only facades
- **Unknown fields in HttpRule**: Preserved in `HttpRuleModel` but logged as warning

## Testing Strategy

| Test Type | Coverage |
|-----------|----------|
| **Unit** | HttpMapper path interpolation, query flattening, body mapping |
| **Unit** | ExtensionRegistry extraction with real proto bytes |
| **Golden** | Full proto → Dart output comparison (update mode available) |
| **Integration** | `CodeGenerator` round-trip: request → response → formatted Dart |
| **Runtime** | Transport factory, ApiException mapping (already exist, expanded) |
