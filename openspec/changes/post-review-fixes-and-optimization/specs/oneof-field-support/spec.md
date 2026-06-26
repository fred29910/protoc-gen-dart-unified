## ADDED Requirements

### Requirement: Parser extracts oneof metadata from DescriptorProto

The system SHALL extract `oneof_decl` and `oneof_index` from `DescriptorProto` and store the oneof group name in `FieldModel.oneofName`.

#### Scenario: field with oneof_index references valid oneof_decl
- **WHEN** a field has `oneof_index` set to a valid index within `oneof_decl` list
- **THEN** `FieldModel.oneofName` SHALL be set to the corresponding `oneof_decl` name

#### Scenario: field without oneof_index
- **WHEN** a field does not have `oneof_index` set
- **THEN** `FieldModel.oneofName` SHALL be `null`

#### Scenario: oneof field appears in generated abstract interface
- **WHEN** a proto method has a oneof field in its input message
- **THEN** the generated abstract interface SHALL include the oneof field with correct type

### Requirement: FieldModel supports oneof metadata

`FieldModel` SHALL expose a `oneofName` field of type `String?` identifying the oneof group to which the field belongs.

#### Scenario: oneofName is consumed by service generator
- **WHEN** `ServiceGenerator` processes methods with oneof-containing messages
- **THEN** generated code SHALL correctly reference the oneof fields

### Requirement: oneof serialization correctness

Generated code SHALL NOT break protobuf oneof serialization semantics where only one field in a oneof group may be set at a time.

#### Scenario: oneof field set/unset produces correct wire format
- **WHEN** a oneof field is set and then another field in the same group is set
- **THEN** the first field SHALL be cleared per protobuf semantics
- **THEN** the serialized output SHALL contain only the last set field
