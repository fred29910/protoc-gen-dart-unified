# Proto Parsing & Validation

**Generated:** 2026-07-15
**Parent:** `AGENTS.md` (root)

## OVERVIEW

Pre-generation input stage — turns protoc `FileDescriptorProto` into internal `ServiceModel`/`MessageModel` trees and validates structure. Pure parsing, no code emission.

## STRUCTURE

```
parser/
├── descriptor_parser.dart   # DescriptorParser: FileDescriptorProto → List<ServiceModel>
├── extension_registry.dart  # createHttpExtensionRegistry(): google.api.http extension
├── input_validator.dart     # InputValidator: structural checks (no mutation)
└── google/api/              # Pre-generated protobuf descriptors (DO NOT EDIT)
    ├── annotations.pb.dart  # Annotations message (http custom option)
    └── http.pb.dart         # HttpRule message
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Parse proto → models | `descriptor_parser.dart` | `parse()` builds services, messages, fields; detects maps/enums/oneofs |
| Extract `google.api.http` | `descriptor_parser.dart` `_extractHttpRule` | Re-parses `MethodOptions` via `ExtensionRegistry` |
| Register http extension | `extension_registry.dart` | `createHttpExtensionRegistry()` — required for HttpRule reads |
| Validate input | `input_validator.dart` | `validate()` → `List<ValidationError>`; empty/no-service/no-method/name-conflict |
| Map/enum/oneof detection | `descriptor_parser.dart` `_parseMessages` | Inspects `DescriptorProto` options & field types |

## CONVENTIONS

- `google/api/*.pb.dart` are generated protobuf descriptors — never hand-edit
- HttpRule extraction re-parses `MethodOptions` from the raw buffer using the extension registry (not the parsed model)
- `InputValidator` only validates — it never modifies or repairs the descriptor
- `DescriptorParser` is the only consumer of `createHttpExtensionRegistry()`

## ANTI-PATTERNS

- Don't hand-edit `google/api/*.pb.dart` — regenerate from protoc
- Don't read HttpRule without the extension registry (returns null silently)
- Don't make `InputValidator` mutate input — validation must be side-effect free
