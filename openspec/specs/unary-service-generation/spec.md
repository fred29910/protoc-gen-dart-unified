# unary-service-generation Specification

## Purpose
TBD - created by archiving change mvp-core-skeleton. Update Purpose after archive.
## Requirements
### Requirement: Unary service facade generation

The system SHALL generate a Dart facade for unary RPC methods that exposes a stable method signature.

#### Scenario: Unary method generated
- **WHEN** a service method is unary
- **THEN** the generated facade exposes a method returning `Future<Response>`

### Requirement: Path parameter binding

The system SHALL map `{field}` path placeholders to Dart expression interpolation.

#### Scenario: Path interpolation
- **WHEN** a path template contains `{id}`
- **THEN** the generated HTTP call uses the request field `id` in the URL path

### Requirement: Query flattening

The system SHALL flatten non-path, non-body fields into query parameters.

#### Scenario: Query parameter generated
- **WHEN** a request contains fields not used by the path template
- **THEN** those fields are emitted as query parameters

