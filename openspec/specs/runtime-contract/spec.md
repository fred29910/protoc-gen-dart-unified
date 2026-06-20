# runtime-contract Specification

## Purpose
TBD - created by archiving change mvp-core-skeleton. Update Purpose after archive.
## Requirements
### Requirement: Runtime API contract

The system SHALL define the core runtime API used by generated services: `Protocol`, `ClientOptions`, `Transport`, `RpcInterceptor`, and `ApiException`.

#### Scenario: Generated service imports runtime contract
- **WHEN** a service facade is generated
- **THEN** it imports the runtime contract types from the shared runtime package

### Requirement: Transport abstraction

The system SHALL provide an abstract transport interface with unary and server-streaming methods.

#### Scenario: Transport interface implemented
- **WHEN** an HTTP or gRPC transport is configured
- **THEN** it satisfies the shared `Transport` interface

### Requirement: Interceptor hook

The system SHALL expose an interceptor hook that can wrap outbound requests and inbound responses.

#### Scenario: Interceptor registration
- **WHEN** an interceptor is added to the client options
- **THEN** generated calls can pass through the interceptor chain

