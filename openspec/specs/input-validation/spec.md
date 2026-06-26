## ADDED Requirements

### Requirement: Method name uniqueness validation

The system SHALL validate that no two methods within the same service share the same name (case-insensitive for Dart compatibility).

#### Scenario: duplicate method names detected
- **WHEN** a proto service defines two methods with names differing only by case (e.g., `getUser` and `GetUser`)
- **THEN** the generator SHALL return a precise error indicating the conflict

#### Scenario: unique method names pass validation
- **WHEN** all methods in a service have unique names
- **THEN** generation SHALL proceed normally

### Requirement: Message type existence validation

The system SHALL validate that all referenced input and output types in service methods exist as defined messages or well-known types.

#### Scenario: missing input type
- **WHEN** a method references an input type that is not defined in any proto file
- **THEN** the generator SHALL return an error with the method name and missing type

#### Scenario: all types exist
- **WHEN** all referenced types are defined in the proto files
- **THEN** generation SHALL proceed normally

### Requirement: Empty input handling

The system SHALL handle empty or minimal inputs without crashing.

#### Scenario: empty service (no methods)
- **WHEN** a proto file defines a service with zero methods
- **THEN** the generator SHALL produce a valid (empty) interface file

#### Scenario: empty message (no fields)
- **WHEN** a proto file defines a message with no fields
- **THEN** the parser SHALL produce a valid `MessageModel` with an empty field list

### Requirement: Reserved word conflict detection

The system SHALL detect when proto identifiers conflict with Dart reserved words and provide a warning or automatic mangling.

#### Scenario: field name is a Dart reserved word
- **WHEN** a proto field is named `class`, `import`, `default`, or other Dart reserved words
- **THEN** the generator SHALL mangle the name (e.g., `class_` suffix) or report an error

## MODIFIED Requirements

### Requirement: Error message granularity (previously informal)

The generator SHALL produce structured error messages including error type, location, and message.

#### Scenario: parse error includes file and line
- **WHEN** a proto file contains a syntax error
- **THEN** the error SHALL include the file name and line number

#### Scenario: generation error includes module name
- **WHEN** a generator fails during code generation
- **THEN** the error SHALL include which generator module failed
