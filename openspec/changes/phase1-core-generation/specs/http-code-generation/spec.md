# http-code-generation Specification

## Purpose
Generate complete Dart service facades with HTTP transport calls, using `code_builder` AST construction for syntactically correct output.

## Requirements

### Requirement: Path parameter interpolation

The system SHALL interpolate `{field}` path placeholders with Dart expression accessors from the request message.

#### Scenario: Simple path field
- **WHEN** a path template is `/v1/users/{id}` and the request has field `id`
- **THEN** the generated code uses string interpolation `"/v1/users/${request.id}"`

#### Scenario: Nested path field
- **WHEN** a path template is `/v1/users/{user.id}` and the request has nested field `user.id`
- **THEN** the generated code accesses `request.user.id`

#### Scenario: Segment wildcard
- **WHEN** a path template contains `{name=segments/*}`
- **THEN** the generated code uses the field `name` with segment expansion

### Requirement: Query parameter flattening

The system SHALL emit non-path, non-body fields as URL query parameters.

#### Scenario: Simple query params
- **WHEN** a request has fields `page` and `limit` not used in path or body
- **THEN** the generated code adds `?page=${request.page}&limit=${request.limit}`

#### Scenario: Nested message query params
- **WHEN** a request has nested message field `filter.name`
- **THEN** the generated code uses dot-notation `filter.name=${request.filter.name}`

#### Scenario: No query params for GET with body:*
- **WHEN** `body: "*"` is set and all fields are consumed by body
- **THEN** no query parameters are generated

### Requirement: Body mapping

The system SHALL map request body according to the `body` field in HttpRule.

#### Scenario: Full body
- **WHEN** `body: "*"` is set
- **THEN** the generated code serializes the entire request message as JSON body

#### Scenario: Field body
- **WHEN** `body: "field_name"` is set
- **THEN** the generated code serializes only the specified sub-field as body

#### Scenario: No body
- **WHEN** the HTTP method is GET or DELETE with no body field
- **THEN** the generated code sends no request body

### Requirement: code_builder AST generation

The system SHALL use `package:code_builder` to construct all generated Dart code.

#### Scenario: Valid Dart output
- **WHEN** any service facade is generated
- **THEN** the output is syntactically valid Dart that passes `dart analyze`

#### Scenario: Proper imports
- **WHEN** a generated file references external types
- **THEN** the generated code includes correct `import` statements via `DartEmitter.scoped()`

### Requirement: Unary method signature

The system SHALL generate unary method signatures returning `Future<Response>`.

#### Scenario: Unary method generated
- **WHEN** a service method has unary input and output
- **THEN** the generated facade exposes `Future<OutputType> methodName(InputType request)`

### Requirement: Server streaming method signature

The system SHALL generate server streaming method signatures returning `Stream<Response>`.

#### Scenario: Server streaming method generated
- **WHEN** a service method has `returns (stream OutputType)`
- **THEN** the generated facade exposes `Stream<OutputType> methodName(InputType request)`

### Requirement: HTTP error mapping

The system SHALL map HTTP errors to `ApiException` subclasses using the gRPC code ↔ HTTP status mapping table.

#### Scenario: DioException mapped
- **WHEN** an HTTP call fails with `DioException` (status 400)
- **THEN** the generated code throws `InvalidArgumentException`

#### Scenario: Timeout mapped
- **WHEN** an HTTP call times out
- **THEN** the generated code throws `RpcTimeoutException`

### Requirement: Service-level transport selection

The system SHALL select transport per-service: if any method in a service has a `google.api.http` annotation, the entire service uses HTTP transport; otherwise gRPC transport.

#### Scenario: Service with mixed annotations
- **WHEN** a service has 3 methods, 1 with `google.api.http` and 2 without
- **THEN** the entire service is generated with HTTP transport
- **AND** methods without annotations throw `UnsupportedError` at runtime

#### Scenario: Service without annotations
- **WHEN** no method in a service has `google.api.http`
- **THEN** the service is generated with gRPC transport only
