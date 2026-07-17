# transport-selection Specification (delta)

## Purpose
Extend the conditional-import split requirement: the generated `unified_runtime.dart` (platform-agnostic entry of the 5-file runtime set) must contain no gRPC implementation code; gRPC implementation lives only in the native conditional-import compilation unit (`unified_transport_native.dart` + per-service `unified_transport_adapter_{service}.dart`).

## MODIFIED Requirements

### Requirement: Conditional import split

The system SHALL use conditional imports to keep Web builds free of gRPC dependencies.

#### Scenario: Web build excludes native transport
- **WHEN** the package is compiled for Web
- **THEN** the generated import graph does not reference `unified_transport_native.dart` or `unified_transport_adapter_*.dart`

#### Scenario: Generated runtime entry contains no gRPC code
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output does not define `GrpcTransport` and does not import `grpc` or `dart:io`

#### Scenario: GrpcTransport implementation isolated to native unit
- **WHEN** gRPC transport is used on Native
- **THEN** `GrpcTransport` is provided by `unified_transport_native.dart` (conditional-import only via `dart.library.io`, not compiled for Web)
