# google-api-http-parser Specification

## Purpose
TBD - created by archiving change mvp-core-skeleton. Update Purpose after archive.
## Requirements
### Requirement: google.api.http custom option extraction

The system SHALL extract `google.api.http` annotations from method options using an `ExtensionRegistry`.

#### Scenario: Annotation is preserved
- **WHEN** a method descriptor contains `(google.api.http) = { get: "/v1/users/{id}" }`
- **THEN** the generator reads the annotation as an `HttpRuleModel` instead of dropping it as an unknown field

### Requirement: HttpRuleModel representation

The system SHALL represent the full `HttpRule` shape, including method kind, path, body, response_body, and additional_bindings.

#### Scenario: Additional bindings are retained
- **WHEN** a method declares multiple HTTP bindings
- **THEN** the model stores each binding without losing the primary rule

