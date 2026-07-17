# HTTP Mapping Engine

**Generated:** 2026-07-15
**Parent:** `AGENTS.md` (root)

## OVERVIEW

Stateless translation layer — converts `HttpRuleModel` path/body/query templates into codegen-ready inputs (`PathMapping`, `BodyMapping`, `QueryField`). Pure functions, no I/O. Consumed by `service_generator.dart` via `HttpMapper`.

## STRUCTURE

```
builder/
├── http_mapper.dart    # HttpMapper: mapPath / flattenQuery / resolveBody / toCamelCase
├── path_mapping.dart   # PathMapping result (literalSegments, pathFieldNames)
├── body_mapping.dart   # BodyMapping result (kind: all | field | none)
└── query_field.dart    # QueryField (name, dartAccessor)
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Parse path template | `http_mapper.dart` `mapPath` | State-machine parser (not regex) for `{field}` / `{field=segs/*}` |
| Resolve query params | `http_mapper.dart` `flattenQuery` | Excludes path fields + body field |
| Resolve body mapping | `http_mapper.dart` `resolveBody` | `"*"` → all, field name → field, empty → none |
| snake→camel | `http_mapper.dart` `toCamelCase` | `page_size` → `pageSize` |
| Path parse result | `path_mapping.dart` | Holds literal segments + field names |
| Body parse result | `body_mapping.dart` | Holds body kind + optional field name |

## CONVENTIONS

- All logic is pure/deterministic — no I/O, no runtime dependencies
- `mapPath` uses a character state-machine, NOT regex (correctness on nested braces)
- `service_generator.dart` is the only caller — `HttpMapper.mapPath` / `flattenQuery` (3 call sites each)
- Results are immutable value objects with `==`/`hashCode`

## ANTI-PATTERNS

- Don't parse path templates with regex — use `HttpMapper.mapPath`
- Don't add I/O or runtime deps here — this layer is platform-agnostic
- Don't duplicate camelCase conversion — reuse `HttpMapper.toCamelCase`
