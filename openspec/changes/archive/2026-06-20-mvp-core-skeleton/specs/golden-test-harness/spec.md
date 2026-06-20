## ADDED Requirements

### Requirement: Golden test fixture support

The system SHALL provide fixture protos and golden output files for generator tests.

#### Scenario: Golden update path
- **WHEN** a fixture proto changes
- **THEN** the test suite can compare generated output against the golden baseline

### Requirement: Custom option test coverage

The system SHALL include a dedicated test that proves `google.api.http` is read through `ExtensionRegistry`.

#### Scenario: Custom option test
- **WHEN** a method option contains a `google.api.http` annotation
- **THEN** the test confirms the annotation is recovered from the parsed descriptor

### Requirement: Formatting idempotency test

The system SHALL verify that generated Dart source is stable under `DartFormatter`.

#### Scenario: Formatter stability
- **WHEN** generated source is formatted once
- **THEN** formatting it a second time produces identical output
