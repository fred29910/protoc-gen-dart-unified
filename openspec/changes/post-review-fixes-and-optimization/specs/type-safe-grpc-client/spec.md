## ADDED Requirements

### Requirement: GrpcClient type abstraction

The system SHALL introduce a typed abstraction for gRPC clients, replacing the current `dynamic` type for `_grpcClient` in generated `Unified<Service>` implementations.

#### Scenario: generated unified service uses typed client
- **WHEN** a gRPC-only service implementation is generated
- **THEN** `_grpcClient` field SHALL use `Object?` type instead of `dynamic`
- **THEN** the generated code SHALL include helper casts for gRPC delegation

#### Scenario: HTTP-only service has no grpcClient field
- **WHEN** all methods have `google.api.http` annotations
- **THEN** the generated `Unified<Service>` class SHALL NOT include any `_grpcClient` field

### Requirement: Type-safe streaming delegation

Generated gRPC server streaming methods SHALL type-check stream responses at compile time rather than runtime.

#### Scenario: server stream return type matches service client
- **WHEN** a gRPC server streaming method is generated
- **THEN** the delegation code SHALL cast the gRPC stream result to the correct `Stream<T>` type using a typed helper

### Requirement: Forward-compatible API

The typed abstraction SHALL allow future introduction of a full gRPC transport interface without breaking generated code.

#### Scenario: new grpc transport interface can be added
- **WHEN** a future version introduces `GrpcClient` interface
- **THEN** existing generated code SHALL compile with minimal migration
