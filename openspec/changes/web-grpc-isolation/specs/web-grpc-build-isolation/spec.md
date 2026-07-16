# web-grpc-build-isolation Specification

## Purpose
确保 Web 编译产物不含 `grpc`/`dart:io` 依赖的编译期隔离机制：生成的 service 文件去 pbgrpc import，生成的单文件 runtime 模板去 GrpcTransport 实现。

## Requirements

### Requirement: Service file excludes pbgrpc import

The system SHALL NOT generate a static `import '*.pbgrpc.dart'` in any generated `*_service.dart` file, regardless of whether the service uses gRPC or HTTP transport.

#### Scenario: gRPC-only service generates no pbgrpc import
- **WHEN** a service has no `google.api.http` annotation (pure gRPC)
- **THEN** the generated `*_service.dart` contains no `import '*.pbgrpc.dart'` directive

#### Scenario: Unified impl uses transport uniformly
- **WHEN** the `Unified<Service>` implementation makes a call
- **THEN** it invokes `_transport.unaryCall` / `_transport.serverStream` (no direct `_grpcClient` reference)

### Requirement: Generated runtime template excludes gRPC implementation

The system SHALL emit a `unified_runtime.dart` single-file template that contains no gRPC implementation code (no `GrpcTransport` class, no `grpc`/`dart:io` import).

#### Scenario: Runtime template has no gRPC class
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output does not define `class GrpcTransport` and does not import `grpc` or `dart:io`

#### Scenario: Runtime template retains GrpcClient interface
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output retains the abstract `GrpcClient` interface and the `createTransport` factory signature

### Requirement: Web build excludes gRPC dependencies

The system SHALL ensure Web compilation does not pull in `grpc` or `dart:io` dependencies through generated output.

#### Scenario: Web compile graph excludes native transport
- **WHEN** the generated package is compiled for Web
- **THEN** the import graph does not reference `transport_native.dart` or `grpc`/`dart:io`

#### Scenario: Web pure-gRPC service fails clearly
- **WHEN** a pure gRPC service is instantiated on Web with a `grpcClient` provided
- **THEN** the system throws `UnsupportedError` stating Web does not support pure gRPC services
