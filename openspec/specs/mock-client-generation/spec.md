# mock-client-generation Specification

## Purpose
TBD - created by archiving change mock-client-test-stubs. Update Purpose after archive.
## Requirements
### Requirement: Generator SHALL produce a mock client file for each service

For every service defined in the proto file, the generator SHALL produce a `*_mock.dart` file in the same output directory as the `*_service.dart` file. The mock file SHALL contain a `MockXxxService` class that `extends Mock implements XxxService` (mockito virtual mocks; no `build_runner`/codegen annotation required).

#### Scenario: Unary service generates mock file
- **WHEN** a proto service has only unary methods (no streaming)
- **THEN** the generator produces `*_mock.dart` containing `class MockXxxService extends Mock implements XxxService {}`

#### Scenario: Service with server streaming generates mock file
- **WHEN** a proto service has server streaming methods
- **THEN** the generator produces `*_mock.dart` with `class MockXxxService extends Mock implements XxxService {}` — mockito's `Mock` supports `Stream<T>` return types virtually (via `noSuchMethod`), so no explicit stream stub code is emitted in the mock file; stream stubs appear as commented templates in the example test file (see `example-test-stub-generation`).

#### Scenario: mock=false disables mock generation
- **WHEN** the `mock` plugin parameter is set to `false`
- **THEN** the generator does NOT produce `*_mock.dart` files

### Requirement: Mock file SHALL follow mockito conventions

The generated mock file SHALL import `package:mockito/mockito.dart` and the service's `*.pb.dart` message types and the `*_service.dart` file. The mock class name SHALL follow the pattern `MockXxxService` where `XxxService` is the abstract service interface name.

#### Scenario: Mock file has correct imports
- **WHEN** the generator creates a mock file for `UserService`
- **THEN** the file imports `package:mockito/mockito.dart`, `user.pb.dart`, and `user_service.dart`

#### Scenario: Mock class implements service interface
- **WHEN** the abstract service interface is `UserService`
- **THEN** the generated mock class is `class MockUserService extends Mock implements UserService {}`

### Requirement: Mock file SHALL be formatted and lint-free

The generated mock file SHALL be formatted with `DartFormatter` and pass `dart analyze` with zero errors.

#### Scenario: Mock file passes dart analyze
- **WHEN** the generator produces a mock file
- **THEN** the file can be analyzed with `dart analyze` without errors

