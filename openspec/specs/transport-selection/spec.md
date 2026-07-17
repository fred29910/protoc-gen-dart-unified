# transport-selection Specification

## Purpose
TBD - created by archiving change mvp-core-skeleton. Update Purpose after archive.
## Requirements
### Requirement: Protocol.auto selection

The system SHALL select the active transport according to the compile-time platform and configured protocol.

#### Scenario: Web forces HTTP
- **WHEN** the target platform is Web
- **THEN** the selected transport is HTTP regardless of `Protocol.auto`

### Requirement: Native transport selection

The system SHALL allow Native builds to use either HTTP or gRPC based on configuration.

#### Scenario: Native auto with grpc configured
- **WHEN** the target platform is Native and `grpc` is configured
- **THEN** `Protocol.auto` selects gRPC

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

