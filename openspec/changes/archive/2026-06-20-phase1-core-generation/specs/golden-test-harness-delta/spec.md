## ADDED Requirements

### Requirement: Full proto-to-Dart golden comparison

The system SHALL compare generated Dart output against golden files for correctness.

#### Scenario: Full proto-to-Dart golden test
- **WHEN** the generator processes `test/fixtures/user.proto`
- **THEN** the generated output matches the golden file `test/goldens/user_service.dart.golden`

### Requirement: Golden update mode

The system SHALL support updating golden files.

#### Scenario: Golden update mode
- **WHEN** the `--update-goldens` flag is passed to the test runner
- **THEN** golden files are regenerated from the current generator output

### Requirement: ExtensionRegistry extraction test

The system SHALL verify HttpRule extraction works correctly.

#### Scenario: ExtensionRegistry extraction test
- **WHEN** a proto method has `(google.api.http) = { get: "/v1/users/{id}" }`
- **THEN** the test confirms the `HttpRuleModel` is correctly extracted (not null, correct kind and path)

### Requirement: HTTP mapping unit tests

The system SHALL test HTTP mapping functions.

#### Scenario: HTTP mapping unit tests
- **WHEN** `HttpMapper.interpolatePath("/v1/users/{id}", request)` is called
- **THEN** the test verifies correct path interpolation output

### Requirement: Query flattening unit tests

The system SHALL test query parameter flattening.

#### Scenario: Query flattening unit tests
- **WHEN** `HttpMapper.flattenQuery(request, usedFields)` is called
- **THEN** the test verifies correct query parameter generation

### Requirement: Body mapping unit tests

The system SHALL test body resolution.

#### Scenario: Body mapping unit tests
- **WHEN** `HttpMapper.resolveBody(request, bodyField)` is called
- **THEN** the test verifies correct body resolution for `*`, named field, and empty cases