# grpc-code-generation Specification

## Purpose
TBD - created by archiving change phase1-core-generation. Update Purpose after archive.
## Requirements
### Requirement: gRPC transport delegation

The system SHALL generate `Unified<Service>` that delegates gRPC calls to the transport returned by `createTransport`, not to a directly-held `*ServiceClient`.

#### Scenario: Unary gRPC call via transport
- **WHEN** a method is configured for gRPC transport
- **THEN** the generated code calls `_transport.unaryCall<Output>(...)` (no `_grpcClient!.unaryCall`)

#### Scenario: gRPC metadata passthrough
- **WHEN** `RpcCallOptions.headers` is set
- **THEN** `GrpcTransport` passes headers as gRPC `CallOptions` metadata

#### Scenario: gRPC timeout passthrough
- **WHEN** `RpcCallOptions.timeout` is set
- **THEN** `GrpcTransport` applies the timeout to the gRPC call

#### Scenario: gRPC cancellation passthrough
- **WHEN** `RpcCancelToken.cancel()` is invoked
- **THEN** `GrpcTransport` cancels the underlying gRPC `ResponseFuture`

### Requirement: gRPC error mapping

The system SHALL map `GrpcError` to `ApiException` subclasses using the gRPC canonical code directly.

#### Scenario: gRPC error code mapped
- **WHEN** a gRPC call fails with `GrpcError.notFound`
- **THEN** the generated code throws `NotFoundException`

### Requirement: Server streaming gRPC

The system SHALL support server streaming via gRPC native `ResponseStream<T>` through `_transport.serverStream`.

#### Scenario: Server streaming gRPC call
- **WHEN** a method has `returns (stream OutputType)` and gRPC transport is active
- **THEN** the generated code returns `Stream<OutputType>` from `_transport.serverStream`

