# sdk-entry-generation Specification

## Purpose
TBD - created by archiving change phase1-core-generation. Update Purpose after archive.
## Requirements
### Requirement: ApiSdk class generation

The system SHALL generate an `ApiSdk` class as the single entry point for all generated services.

#### Scenario: ApiSdk with single service
- **WHEN** a proto file contains one service `UserService`
- **THEN** the generated `ApiSdk` exposes `userService` as a lazy-initialized property

#### Scenario: ApiSdk with multiple services
- **WHEN** a proto file contains multiple services
- **THEN** the generated `ApiSdk` exposes a property for each service

#### Scenario: ApiSdk constructor
- **WHEN** `ApiSdk` is constructed
- **THEN** it accepts `ClientOptions` and initializes the transport and interceptors

### Requirement: Protocol.auto routing

The generated `ApiSdk` SHALL implement the `Protocol.auto` selection rules.

#### Scenario: Web forces HTTP
- **WHEN** `Protocol.auto` is configured on Web
- **THEN** all service methods use HTTP transport

#### Scenario: Native prefers gRPC
- **WHEN** `Protocol.auto` is configured on Native with gRPC available
- **THEN** all service methods use gRPC transport

### Requirement: Interceptor chain

The generated `ApiSdk` SHALL support interceptor injection.

#### Scenario: Interceptor registered
- **WHEN** an interceptor is added via `ApiSdk.addInterceptor()`
- **THEN** all service calls pass through the interceptor chain before reaching the transport

