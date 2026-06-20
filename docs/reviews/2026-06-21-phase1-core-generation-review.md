# Code Review — Phase 1 Core Generation

- **Date:** 2026-06-21
- **Branch:** `feature/20260620/phase1-core-generation`
- **Scope:** Entire project reviewed against `docs/design.md` (Phase 1 deliverables)
- **Files reviewed:** 28 source/test files (~1,381 LoC) + design doc + golden output
- **Verdict:** 🔴 **BLOCKED**

## Summary

Tests are green (41/41) and the plan is marked "all 7 tasks done" — **but the generated SDK does not compile, and the project's core feature (`google.api.http` REST transcoding) is not actually wired into code generation.** The green test suite asserts the broken output as correct.

**Issues: 5 CRITICAL · 7 HIGH · 7 MEDIUM**

The gap between "all 7 tasks done / 41 tests green" and reality is the core risk: the generator emits non-compiling Dart, and the central feature (real `google.api.http` REST transcoding) exists only as comments — the runtime falls back to the connect-style envelope the design was created to avoid. The test suite is green because it asserts substrings of the broken output rather than compiling it.

---

## 🔴 CRITICAL

### C1 — Generated code uses raw proto type names → does not compile
`lib/src/parser/descriptor_parser.dart:24-25` passes `m.inputType` / `m.outputType` verbatim (e.g. `.user.v1.User`), and `lib/src/generators/service_generator.dart:66-75` emits them directly into signatures and generics. Proto fully-qualified names (leading dot, dotted package) are **not** valid Dart identifiers.

Confirmed: analyzing `Future<.user.v1.User> getUser(...)` yields 7 syntax errors (`missing_identifier`, `expected_type_name`, `undefined_class 'user'`…). Every generated method is broken.

**Fix:** Map proto FQNs → Dart class names (strip leading `.`, drop package, take last segment) and track the import for the message file. This is the missing parser→model→builder mapping step.

### C2 — Generated unary HTTP bodies `await` without `async` → does not compile
`lib/src/generators/service_generator.dart:94-109` never sets `MethodModifier.async`, but `_buildHttpMethodBody` (line 150) emits `final response = await _transport.unaryCall(...)`.

Confirmed: `await_in_wrong_context` + `return_of_invalid_type` compiler errors.

**Fix:** Set `..modifier = MethodModifier.async` for unary HTTP/gRPC method bodies (gRPC unary returns the future directly, so only the `await` variant needs `async`).

### C3 — The core deliverable (google.api.http transcoding) is NOT generated — only commented
This is the headline. Design §"立项前提" line 31 states the entire reason to not use connect-dart is **real RESTful paths** (`GET /v1/users/{id}`). But:

- `HttpMapper`, `PathMapping`, `QueryField`, `BodyMapping` (`lib/src/builder/*`) are **dead code** — never called by `ServiceGenerator` or anything else.
- The generated method body (`service_generator.dart:147-156`) puts the path/method/body into **comments only**, then calls `_transport.unaryCall('UserService', 'getUser', request)`.
- `HttpTransport.unaryCall` (`lib/src/runtime/transport_native.dart:30-39`, `lib/src/runtime/transport_web.dart:26-35`) issues `POST /$serviceName/$methodName` with `data: request` (a non-serialized proto object) — i.e. **exactly the connect-style `POST /Service/Method` envelope the design explicitly rejects.**

Net: path binding, query flattening, and body mapping — the whole Phase 1 HTTP-mapping task — are absent from the product while the plan claims completion.

**Fix:** Wire `HttpMapper` outputs into `_buildHttpMethodBody` to emit real `dio.<verb>(interpolatedPath, queryParameters:…, data:…)` calls and serialize via `toProto3Json()`, and have the transport carry the resolved verb/path/query/body rather than a synthetic envelope.

### C4 — ApiSdk service field is non-nullable, non-`late`, uninitialized → does not compile
Golden output `test/goldens/user_service.dart.golden:35`: `UserService userService;` declared, then assigned in the constructor *body* (`:30`). A non-nullable field not in the initializer list and not `late` is a compile error. (`service_generator.dart:191-194` sets `late = true`, but the emitted golden lacks `late` — the actual committed output is what ships.)

**Fix:** Ensure `late` is emitted (or initialize in the initializer list), then compile-check the golden.

### C5 — Golden baseline is invalid Dart and tests codify the bugs
`test/goldens/user_service.dart.golden` is non-compiling (C1/C2/C4 all visible in it), yet it's committed as the "expected" baseline. Worse, `test/generator_integration_test.dart:35,61,95` assert `contains('Future<.user.v1.User> getUser(')` — the tests **lock in the broken output**. Design lines 123-125 & 514 mandate `dart analyze` zero-warning as a hard CI gate on *generated artifacts*; that gate does not exist.

**Fix:** Add a golden-compile gate: write generated output to a temp package and run `dart analyze` on it in CI. Re-baseline goldens only after C1-C4 are fixed.

---

## 🟠 HIGH

**H1 — Wrong import path for the message file.** `service_generator.dart:48` builds `'../${service.name.toLowerCase()}.pb.dart'` → `userservice.pb.dart`, but the proto is `user.proto` → `user.pb.dart`. Import is derived from the *service* name, not the *file* name; it won't resolve. Derive from `FileDescriptorProto.name`.

**H2 — Format failures silently swallowed (violates hard-gate design).** `service_generator.dart:39-41` and `lib/src/format_formatter.dart:8-10` catch `FormatterException` and return raw, unformatted source. Design lines 122-125 require format failure to be a hard error. This is precisely why the broken golden slipped through looking plausible. Let it throw (or surface a generation error).

**H3 — `Protocol.auto` adaptive routing not implemented (Phase 1 deliverable).** `transport_factory`/`transport_native`/`transport_web` always return `HttpTransport`, ignoring `ClientOptions.protocol` entirely. The design's decision table (Web→http, Native+grpc→grpc, design lines 78-84) has no runtime implementation. `GrpcTransport` is never constructed.

**H4 — All-or-nothing per-service transport.** `_useHttp` (`service_generator.dart:18`) flips the *entire* service to HTTP if *any* method has an http rule; other methods then `throw UnsupportedError`, and the service never imports `pbgrpc`. Routing should be per-method.

**H5 — Parsed HttpRule features never used.** `additional_bindings`, `response_body`, `{name=segments/*}` deep templates, query flattening, and WKT path/query encoding are parsed into `HttpRuleModel` but never emitted (consequence of C3). Body `field` mapping emits `request.${body}` unvalidated (`service_generator.dart:137`).

**H6 — `_extractHttpRule` silently swallows all errors.** `descriptor_parser.dart:74` `catch (_) { return null }` re-introduces the exact failure mode the design warns about (line 116: annotations silently dropped as unknown fields). A read failure silently demotes the method. Don't swallow; at minimum log/propagate.

**H7 — Descriptor parser correctness.** `descriptor_parser.dart:42-60`: only top-level `file.messageType` parsed (no nested types); `isMap` heuristic is wrong — `type==TYPE_MESSAGE && typeName.isNotEmpty` flags **every** message field as a map; `fullName` is set to the short name, not the package-qualified name.

---

## 🟡 MEDIUM

- **M1 — `dart analyze` reports 33 issues** (1 unused-field warning, 7 unused-import warnings in tests, `print` in `golden_test.dart:60`, `implementation_imports`, many `prefer_const`). Design requires zero. Not met.
- **M2 — Fragile private imports.** `generator.dart:2` & `descriptor_parser.dart:2` import `package:protoc_plugin/src/gen/...` (`implementation_imports`) — breaks across protoc_plugin versions.
- **M3 — Duplicated, drifting status maps.** The reverse HTTP→gRPC switch is copy-pasted in `transport_native.dart:67-84` and `transport_web.dart:60-76`, and diverges from the canonical `http_status_mapping.dart` (which is itself never referenced by generated code). Single-source it.
- **M4 — `_clients` unused** in `GrpcTransport` (`transport_native.dart:114`); and the `createTransport` doc ("or null if gRPC is needed") contradicts the code (always returns `HttpTransport`).
- **M5 — Plugin parameter parsing absent.** `args` dependency is declared but unused; none of `single_file/protocol/transport/use_dio/...` (design "插件参数") are implemented.
- **M6 — `grpc` dependency unexercised.** `GrpcTransport` is throw-only; the conditional-import tree-shaking design (lines 380-396) is wired in `transport_factory.dart` but never actually splits a grpc path, since native also returns HTTP.
- **M7 — Hardcoded language version `Version(3,10,0)`** duplicated in `service_generator.dart:36` and `format_formatter.dart:5`; should be centralized/derived.

---

## ✅ What's solid

- `api_exception.dart` — all 17 canonical codes present, clean. `http_status_mapping.dart` — full 17-code coverage matching grpc-gateway. `protocol.dart` / `client_options.dart` — clean.
- `HttpMapper.mapPath` state-machine parser is well-written and tested (`test/builder/http_mapper_test.dart`) — it just isn't *connected* to generation (C3).
- `extension_registry.dart` + the ExtensionRegistry re-parse approach is correct and has a dedicated test — the right solution to the design's key risk.

---

## Recommended path to unblock

**Minimum to unblock:** C1, C2, C4 (make output compile) → C3 (wire `HttpMapper` into generation) → C5 (add a golden-compile gate and re-baseline).

I'd recommend re-opening the Phase 1 "Unary 调用" and "自适应路由" tasks rather than treating them as done.
