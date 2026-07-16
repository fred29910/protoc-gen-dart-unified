# transport-selection Specification (delta)

## Purpose
Extend the conditional-import split requirement: the generated `unified_runtime.dart` single file must contain no gRPC implementation code; gRPC implementation lives only in the native conditional-import compilation unit.

## Requirements

### Requirement: Conditional import split

The system SHALL use conditional imports to keep Web builds free of gRPC dependencies.

#### Scenario: Web build excludes native transport
- **WHEN** the package is compiled for Web
- **THEN** the generated import graph does not reference the native transport file

#### Scenario: Generated runtime template contains no gRPC code
- **WHEN** the `RuntimeInlineGenerator` emits `unified_runtime.dart`
- **THEN** the output does not define `GrpcTransport` and does not import `grpc` or `dart:io`

#### Scenario: GrpcTransport implementation isolated to native unit
- **WHEN** gRPC transport is used on Native
- **THEN** `GrpcTransport` is provided by `transport_native.dart` (conditional-import only, not compiled for Web)
