# dart-generator-scaffold Specification

## Purpose
TBD - created by archiving change mvp-core-skeleton. Update Purpose after archive.
## Requirements
### Requirement: Dart protoc plugin scaffold

The system SHALL provide a Dart executable that reads a `CodeGeneratorRequest` from stdin and writes a `CodeGeneratorResponse` to stdout.

#### Scenario: Plugin entrypoint accepts protoc request
- **WHEN** the executable is invoked by protoc with a valid `CodeGeneratorRequest`
- **THEN** it parses the request and emits a well-formed `CodeGeneratorResponse`

### Requirement: Descriptor traversal

The system SHALL traverse `FileDescriptorProto` values to discover services and methods.

#### Scenario: Service discovery
- **WHEN** a proto file contains one or more `ServiceDescriptorProto` entries
- **THEN** the generator records each service name and method list for later generation

### Requirement: Generated file naming

The system SHALL produce generated Dart files using deterministic names derived from proto service/package names.

#### Scenario: Stable generated filename
- **WHEN** a service named `UserService` exists in package `user`
- **THEN** the generated file name is stable and reproducible across runs

