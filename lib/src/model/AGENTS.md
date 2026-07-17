# Internal Data Models

**Generated:** 2026-07-17
**Parent:** `AGENTS.md` (root)

## OVERVIEW

Immutable value-object layer — the intermediate representation `DescriptorParser` produces and every generator consumes. Pure data, no logic, no I/O.

## STRUCTURE

```
model/
├── service_model.dart      # ServiceModel: name, protoFileName, methods, messages
├── method_model.dart       # MethodModel: in/out types, httpRule, streaming flags
├── message_model.dart      # MessageModel: fields + nested enums
├── field_model.dart        # FieldModel: type, repeated/optional/map/oneof/enum flags
├── enum_model.dart         # EnumModel / EnumValueModel
└── http_rule_model.dart    # HttpRuleModel: kind/path/body + additionalBindings
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Top-level service shape | `service_model.dart` | Root of the parsed tree passed to generators |
| Per-RPC contract | `method_model.dart` | `httpRule != null` drives per-service HTTP vs gRPC choice |
| Field shape + flags | `field_model.dart` | `isMap`/`isEnum`/`oneofName` drive codegen branching |
| HTTP verb/path/body | `http_rule_model.dart` | Output of `DescriptorParser._mapHttpRule` |

## CONVENTIONS

- All models are `const`-constructable immutable classes (value equality via `equatable`-free hand-rolled `==`).
- `MethodModel.inputType`/`outputType` are stripped last-segment type names (e.g. `GetUserRequest`), not fully-qualified.
- `HttpRuleModel.kind` is the lowercased verb string (`get`/`post`/.../`custom`); `additionalBindings` carries `additional_bindings` (unused in client codegen — primary binding only).
- `FieldModel.mapKeyType`/`mapValueType` are only populated when `isMap == true` (detected via `options.mapEntry` on the entry message).

## ANTI-PATTERNS

- Don't put transformation logic in models — they are dumb carriers; logic lives in `builder/` and `generators/`.
- Don't read proto types from these models expecting fully-qualified names — they are stripped.
- Don't rely on `additionalBindings` for client generation — only the primary `HttpRuleModel` is used.
