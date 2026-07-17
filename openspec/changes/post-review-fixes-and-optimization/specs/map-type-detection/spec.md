## ADDED Requirements

### Requirement: Precise map type detection

The system SHALL detect protobuf `map` fields by verifying the field's type is `TYPE_MESSAGE` and its type name corresponds to a message with exactly two fields named `key` and `value`.

#### Scenario: standard map field detected correctly
- **WHEN** a field is defined as `map<string, int32> tags = 1`
- **THEN** `FieldModel.isMap` SHALL be `true`
- **THEN** `FieldModel.mapKeyType` SHALL be `'string'`
- **THEN** `FieldModel.mapValueType` SHALL be `'int32'`

#### Scenario: non-map TYPE_MESSAGE not misclassified
- **WHEN** a field references a regular message type with more than 2 fields
- **THEN** `FieldModel.isMap` SHALL be `false`

#### Scenario: TYPE_MESSAGE with 2 non-key/value fields
- **WHEN** a field references a message type with 2 fields named differently from `key` and `value`
- **THEN** `FieldModel.isMap` SHALL be `false`

### Requirement: map field serialization in generated code

Generated code SHALL correctly serialize protobuf map fields using `toProto3Json()` for HTTP/JSON transport.

#### Scenario: map fields in HTTP body mapping
- **WHEN** a request message contains map fields and `body: "*"` is used
- **THEN** the generated HTTP body code SHALL include the map fields in serialized JSON
