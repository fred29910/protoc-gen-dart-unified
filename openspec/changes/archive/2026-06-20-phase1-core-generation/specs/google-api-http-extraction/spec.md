## ADDED Requirements

### Requirement: ExtensionRegistry registration

The system SHALL register the `Annotations.http` extension (field 72295728 on `MethodOptions`) in the `ExtensionRegistry` used during descriptor parsing.

#### Scenario: Registry contains http extension
- **WHEN** `createHttpExtensionRegistry()` is called
- **THEN** the returned registry contains the `Annotations.http` extension field

#### Scenario: Vendored descriptor files
- **WHEN** the generator parses method options
- **THEN** it uses vendored `google/api/http.pb.dart` and `google/api/annotations.pb.dart` for extension registration

### Requirement: MethodOptions re-parse

The system SHALL re-parse `MethodDescriptorProto.options` bytes through `mergeFromBuffer(bytes, registry)` to extract custom options.

#### Scenario: HttpRule extracted from method options
- **WHEN** a method has `(google.api.http) = { get: "/v1/users/{id}" }`
- **THEN** the parser produces an `HttpRuleModel` with `kind: "get"` and `path: "/v1/users/{id}"`

#### Scenario: Method without annotation
- **WHEN** a method has no `google.api.http` annotation
- **THEN** the parser returns `null` for `HttpRuleModel` (not an error)

### Requirement: Full HttpRule mapping

The system SHALL map all `HttpRule` fields to `HttpRuleModel`: `kind`, `path`, `body`, `response_body`, and `additional_bindings`.

#### Scenario: Additional bindings preserved
- **WHEN** a method declares multiple HTTP bindings
- **THEN** `HttpRuleModel.additionalBindings` contains each secondary binding

#### Scenario: Body mapping captured
- **WHEN** `body: "*"` or `body: "field_name"` is set
- **THEN** `HttpRuleModel.body` contains the exact string value