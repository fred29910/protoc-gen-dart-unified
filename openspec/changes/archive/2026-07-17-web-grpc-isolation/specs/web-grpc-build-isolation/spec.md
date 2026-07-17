# web-grpc-build-isolation Specification

## Purpose
确保 Web 编译产物不含 `grpc`/`dart:io` 依赖的编译期隔离机制：生成的 service 文件去 pbgrpc import，生成的 runtime 改为由 5 文件条件导入集合（`unified_runtime.dart` + `unified_transport_{factory,native,web,stub}.dart`）隔离 gRPC 实现，其中 `unified_runtime.dart` 本身不含 gRPC 实现代码。

## ADDED Requirements

### Requirement: Service file excludes pbgrpc import

The system SHALL NOT generate a static `import '*.pbgrpc.dart'` in any generated `*_service.dart` file, regardless of whether the service uses gRPC or HTTP transport.

#### Scenario: gRPC-only service generates no pbgrpc import
- **WHEN** a service has no `google.api.http` annotation (pure gRPC)
- **THEN** the generated `*_service.dart` contains no `import '*.pbgrpc.dart'` directive

#### Scenario: Unified impl uses transport uniformly
- **WHEN** the `Unified<Service>` implementation makes a call
- **THEN** it invokes `_transport.unaryCall` / `_transport.serverStream` (no direct `_grpcClient` reference)

### Requirement: Generated runtime set excludes gRPC implementation from platform-agnostic files

The system SHALL emit a `unified_runtime.dart` (the platform-agnostic entry of the 5-file runtime set) that contains no gRPC implementation code (no `GrpcTransport` class, no `grpc`/`dart:io` import). The gRPC implementation lives only in the native-only modules `unified_transport_native.dart` and the per-service `unified_transport_adapter_{service}.dart`, both reachable solely via conditional imports on `dart.library.io`.

#### Scenario: Runtime entry has no gRPC class
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output does not define `class GrpcTransport` and does not import `grpc` or `dart:io`

#### Scenario: Runtime entry retains GrpcClient interface
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output retains the abstract `GrpcClient` interface and `createTransport` remains reachable (re-exported via `unified_transport_factory.dart`)

### Requirement: Web build excludes gRPC dependencies

The system SHALL ensure Web compilation does not pull in `grpc` or `dart:io` dependencies through generated output.

#### Scenario: Web compile graph excludes native transport
- **WHEN** the generated package is compiled for Web
- **THEN** the import graph does not reference `unified_transport_native.dart`, `unified_transport_adapter_*.dart`, or `grpc`/`dart:io`

#### Scenario: Web pure-gRPC service fails clearly
- **WHEN** a pure gRPC service is instantiated on Web with a `grpcClient` provided
- **THEN** the system throws `UnsupportedError` stating Web does not support pure gRPC services
