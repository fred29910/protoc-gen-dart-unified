## ADDED Requirements

### Requirement: Parser extracts EnumDescriptorProto definitions

The system SHALL extract `EnumDescriptorProto` entries from `FileDescriptorProto.enumType` and store them in a new `EnumModel` class.

#### Scenario: enum type is parsed from proto descriptor
- **WHEN** a `.proto` file defines an `enum` with multiple values
- **THEN** the parser SHALL extract each enum value name, number, and generate a compliant Dart enum name

#### Scenario: enum with aliased values
- **WHEN** an enum has `allow_alias` option set and duplicate numeric values
- **THEN** the parser SHALL extract all aliased names

### Requirement: Dart enum generation from proto enum

The generated Dart code SHALL produce a valid Dart `enum` type for each proto `enum` definition.

#### Scenario: basic enum generation
- **WHEN** a proto enum `Color { COLOR_RED = 0; COLOR_GREEN = 1; COLOR_BLUE = 2; }` is processed
- **THEN** generated Dart code SHALL contain `enum Color { colorRed, colorGreen, colorBlue; }`

#### Scenario: enum with default value (0)
- **WHEN** the first enum value is `ENUM_TYPE_UNSPECIFIED = 0` (proto3 default)
- **THEN** generated Dart enum SHALL include this value for wire compatibility

### Requirement: Generated code uses concrete Dart enum types

The system SHALL reference generated Dart `enum` types in service method signatures where enum fields appear in request/response messages.

#### Scenario: enum field in method signature
- **WHEN** a message field is of enum type
- **THEN** the generated service interface method SHALL use the Dart `enum` type (not `int` or `String`)
