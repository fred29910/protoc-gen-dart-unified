## ADDED Requirements

### Requirement: Generator registry mechanism

The system SHALL provide a `Map<String, Generator>` registry allowing generators to be registered by key, replacing hardcoded generator instantiation in `CodeGenerator.generate()`.

#### Scenario: register and invoke a generator
- **WHEN** a `Generator` is registered with key `'service'`
- **THEN** passing key `'service'` to the generator registry SHALL return the generator instance
- **THEN** calling `generate()` on the returned instance SHALL produce valid generated output

#### Scenario: unknown generator key returns null
- **WHEN** a key that has not been registered is requested
- **THEN** the registry SHALL return `null` (not throw)

### Requirement: Parallel service generation

The system SHALL support generating multiple service files in parallel using Dart concurrency primitives.

#### Scenario: parallel generation produces same output as sequential
- **WHEN** generating N services in parallel mode
- **THEN** the set of output files SHALL be identical to sequential generation

#### Scenario: parallel generation handles errors gracefully
- **WHEN** one service fails during parallel generation
- **THEN** the error SHALL be collected and reported without crashing other services

### Requirement: Streaming output model

The system SHALL support incremental output delivery to avoid holding all generated files in memory simultaneously.

#### Scenario: large service set generates incrementally
- **WHEN** generating 50+ services with streaming output enabled
- **THEN** peak memory usage SHALL NOT exceed the size of the largest single generated file by more than 50%

### Requirement: Concurrent-safe Input validation

Input validation SHALL run before service generation and SHALL be safe under concurrent access.

#### Scenario: validation runs before parallel dispatch
- **WHEN** parallel generation is enabled
- **THEN** validation SHALL complete before dispatching any services to generators
- **THEN** invalid input SHALL short-circuit the entire generation with a clear error
