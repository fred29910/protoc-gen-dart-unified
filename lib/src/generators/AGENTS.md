# Code Generators

**Generated:** 2026-06-26
**Parent:** `AGENTS.md` (root)

## OVERVIEW

Code generation core — 4 generators that produce service files, mocks, example tests, and the self-contained runtime. `code_builder` + `DartFormatter` stack. ~1500 LOC combined.

## STRUCTURE

```
generators/
├── service_generator.dart        # 497 LOC — interface + Unified impl + ApiSdk
├── runtime_inline_generator.dart # 837 LOC template — emits unified_runtime.dart
├── mock_service_generator.dart   # 60 LOC — mockito-based Mock class
└── example_test_generator.dart   # 108 LOC — test scaffold with stubs
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Main service codegen | `service_generator.dart` | Abstract interface, Unified impl, ApiSdk entry class |
| HTTP method generation | `service_generator.dart` lines 238–422 | Path mapping, body mapping, query params, SSE body |
| gRPC method generation | `service_generator.dart` lines 326–421 | Delegates to `*pbgrpc.dart` |
| Interceptor chain wrapping | `service_generator.dart` lines 202–228 | Builds chain from _interceptors list |
| Inline runtime emission | `runtime_inline_generator.dart` | Single `generate()` method returning full source string |
| Mock generation | `mock_service_generator.dart` | Extends Mockito's Mock, implements service |
| Example test generation | `example_test_generator.dart` | group/test per method with mockito stubs |

## CONVENTIONS

- All generators use `code_builder` (Library → DartEmitter → DartFormatter pipeline)
- `DartEmitter.scoped(useNullSafetySyntax: true)` for null safety in generated code
- Generated files always start with `// ignore_for_file: type=lint`
- Proto PascalCase → snake_case for file names, camelCase for method names
- `Version(3, 10, 0)` language version for DartFormatter
- Mock/test generators import `unified_runtime.dart` (local, not package)

## ANTI-PATTERNS

- Don't add source-level dependencies to generated output — only `unified_runtime.dart` and protobuf types
- Don't put runtime logic in generators — keep codegen separate from runtime
- Don't use `dart:io` in generated code — runtime_inline_generator is platform-agnostic (web-compatible)
- Don't add huge templates to service_generator — move to runtime_inline_generator when >50 lines inline
