# golden-test-harness Delta Specification

## Change Type: Modified

## Delta: Add real golden comparison tests (was scaffold-only)

The existing `golden-test-harness` spec defined the test structure but the tests were placeholders. This delta adds real golden comparison requirements.

### Added Requirements

#### Scenario: Full proto-to-Dart golden test
- **WHEN** the generator processes `test/fixtures/user.proto`
- **THEN** the generated output matches the golden file `test/goldens/user_service.dart.golden`

#### Scenario: Golden update mode
- **WHEN** the `--update-goldens` flag is passed to the test runner
- **THEN** golden files are regenerated from the current generator output

#### Scenario: ExtensionRegistry extraction test
- **WHEN** a proto method has `(google.api.http) = { get: "/v1/users/{id}" }`
- **THEN** the test confirms the `HttpRuleModel` is correctly extracted (not null, correct kind and path)

#### Scenario: HTTP mapping unit tests
- **WHEN** `HttpMapper.interpolatePath("/v1/users/{id}", request)` is called
- **THEN** the test verifies correct path interpolation output

#### Scenario: Query flattening unit tests
- **WHEN** `HttpMapper.flattenQuery(request, usedFields)` is called
- **THEN** the test verifies correct query parameter generation

#### Scenario: Body mapping unit tests
- **WHEN** `HttpMapper.resolveBody(request, bodyField)` is called
- **THEN** the test verifies correct body resolution for `*`, named field, and empty cases
