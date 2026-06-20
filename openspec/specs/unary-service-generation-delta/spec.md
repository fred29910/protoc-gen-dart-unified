# unary-service-generation-delta Specification

## Purpose
TBD - created by archiving change phase1-core-generation. Update Purpose after archive.
## Requirements
### Requirement: Generated method with HTTP call

The system SHALL generate HTTP transport method bodies for annotated methods.

#### Scenario: Generated method with HTTP call
- **WHEN** a unary method has a `google.api.http` annotation
- **THEN** the generated facade method makes an HTTP call with correct path, query params, and body

### Requirement: Generated method with gRPC delegation

The system SHALL generate gRPC delegation for non-annotated methods.

#### Scenario: Generated method with gRPC delegation
- **WHEN** a unary method has no `google.api.http` annotation
- **THEN** the generated facade method delegates to the `*ServiceClient` gRPC stub

### Requirement: Generated method error handling

The system SHALL map transport errors to ApiException.

#### Scenario: Generated method error handling
- **WHEN** a generated method catches a transport-level exception
- **THEN** it maps it to the corresponding `ApiException` subclass

### Requirement: code_builder usage

The system SHALL use code_builder AST for code generation.

#### Scenario: code_builder usage
- **WHEN** any service facade is generated
- **THEN** the code is constructed via `package:code_builder` AST nodes, not string concatenation

### Requirement: gRPC fallback for unannotated methods

The system SHALL generate gRPC-only facades when no annotations exist.

#### Scenario: gRPC fallback for unannotated methods
- **WHEN** a service has no `google.api.http` annotations on any method
- **THEN** the generated facade delegates all methods to the `*ServiceClient` gRPC stub
- **AND** the generated import includes `../user.pbgrpc.dart`

