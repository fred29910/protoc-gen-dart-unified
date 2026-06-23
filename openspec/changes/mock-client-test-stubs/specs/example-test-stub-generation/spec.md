## ADDED Requirements

### Requirement: Generator SHALL produce an example test file for each service

For every service defined in the proto file, the generator SHALL produce a `*_example_test.dart` file in the same output directory. The example test file SHALL contain a test group for each service method with a basic stub template.

#### Scenario: Example test file has correct structure
- **WHEN** the generator creates an example test file for `UserService` with methods `getUser` and `createUser`
- **THEN** the file contains a `main()` function with `group('UserService', ...)` containing test stubs for each method

#### Scenario: Example test imports required dependencies
- **WHEN** the generator creates an example test file
- **THEN** the file imports `package:test/test.dart`, the mock file, and the service file

#### Scenario: mock=false disables example test generation
- **WHEN** the `mock` plugin parameter is set to `false`
- **THEN** the generator does NOT produce `*_example_test.dart` files

### Requirement: Example test SHALL include stub templates for each method

For each unary method, the example test SHALL include a `test()` block with `when(...).thenReturn(...)` stub template. For server streaming methods, the stub SHALL use `Stream.value()`.

#### Scenario: Unary method stub template
- **WHEN** the service has a unary method `getUser(GetUserRequest) → Future<User>`
- **THEN** the example test contains a test block with `when(mockUserService.getUser(any)).thenAnswer((_) async => User())`

#### Scenario: Server streaming method stub template
- **WHEN** the service has a server streaming method `watchUser(GetUserRequest) → Stream<User>`
- **THEN** the example test contains a test block with `when(mockUserService.watchUser(any)).thenAnswer((_) => Stream.value(User()))`

### Requirement: Example test file SHALL be formatted and lint-free

The generated example test file SHALL be formatted with `DartFormatter` and pass `dart analyze` with zero errors.

#### Scenario: Example test file passes dart analyze
- **WHEN** the generator produces an example test file
- **THEN** the file can be analyzed with `dart analyze` without errors (assuming user has test + mockito dependencies)
