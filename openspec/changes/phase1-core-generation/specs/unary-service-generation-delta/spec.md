# unary-service-generation Delta Specification

## Change Type: Modified

## Delta: Implement actual code generation (was scaffold-only)

The existing `unary-service-generation` spec defined the facade structure but the implementation only produced a TODO stub. This delta adds the concrete code generation requirements.

### Added Requirements

#### Scenario: Generated method with HTTP call
- **WHEN** a unary method has a `google.api.http` annotation
- **THEN** the generated facade method makes an HTTP call with correct path, query params, and body

#### Scenario: Generated method with gRPC delegation
- **WHEN** a unary method has no `google.api.http` annotation
- **THEN** the generated facade method delegates to the `*ServiceClient` gRPC stub

#### Scenario: Generated method error handling
- **WHEN** a generated method catches a transport-level exception
- **THEN** it maps it to the corresponding `ApiException` subclass

#### Scenario: code_builder usage
- **WHEN** any service facade is generated
- **THEN** the code is constructed via `package:code_builder` AST nodes, not string concatenation

#### Scenario: gRPC fallback for unannotated methods
- **WHEN** a service has no `google.api.http` annotations on any method
- **THEN** the generated facade delegates all methods to the `*ServiceClient` gRPC stub
- **AND** the generated import includes `../user.pbgrpc.dart`
