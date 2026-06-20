## ADDED Requirements

### Requirement: ApiException hierarchy

The system SHALL define an `ApiException` base type and canonical subclasses for common gRPC error codes.

#### Scenario: Canonical mapping
- **WHEN** an HTTP status corresponds to a gRPC canonical code
- **THEN** the generated runtime maps it to the matching `ApiException` subclass

### Requirement: Status code mapping table

The system SHALL include a mapping table covering the 17 canonical gRPC codes.

#### Scenario: Full coverage
- **WHEN** a canonical gRPC code is present
- **THEN** the runtime can map it to the corresponding HTTP status and exception type
