## ADDED Requirements

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
- **THEN** the generated import graph does not reference the native transport file
