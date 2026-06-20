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
