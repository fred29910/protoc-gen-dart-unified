# Verification Report — web-grpc-isolation

**Date**: 2026-07-17
**Change**: web-grpc-isolation
**Phase**: verify (full mode)
**Verify result**: PASS

## Scope

Web-build isolation of gRPC: pure-gRPC services no longer pull `grpc`/`dart:io`
into Web builds. Implemented via the confirmed **A1** (5-file conditional-import
runtime set) + **O-C** (global parameterless native file + per-service adapter)
design decisions.

## Verification Mode: FULL

- Tasks: 21 (threshold 3) → full
- Delta specs: 3 capabilities (threshold 1) → full
- Changed files: 17+ (threshold 4) → full
- `review_mode`: thorough (batched reviews done in build phase: Batch 1/2/3 all PASS/APPROVED)

## Checks (full verification)

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | tasks.md all complete `[x]` | PASS | 21/21 checked (rewritten to reflect realized O-C scope) |
| 2 | Implementation matches design.md decisions | PASS | A1 5-file set + O-C per-service adapter present in `runtime_inline_generator.dart` + `generator_registry.dart` |
| 3 | Implementation matches Design Doc (`docs/superpowers/specs/2026-07-16-...`) | PASS | §1/§2/§7 describe A1 + O-C; code matches |
| 4 | Delta spec scenarios pass | PASS | see below |
| 5 | proposal.md goals met | PASS | Web no longer fails to build pure-gRPC service SDKs |
| 6 | delta spec ↔ design doc no contradiction | PASS | all 3 specs aligned to `unified_transport_*` naming (transport-selection spec updated this verify) |
| 7 | Design doc locatable | PASS | `docs/superpowers/specs/2026-07-16-web-grpc-isolation-design.md` exists |

### Delta spec scenario evidence (fresh, generated-output based)

**web-grpc-build-isolation** (verified by programmatic generation + `test/web_isolation_test.dart`):
- Pure-gRPC `echo_service.dart` has NO `*.pbgrpc.dart` import ✓
- `Unified` calls `_transport.unaryCall` (no `_grpcClient`) ✓
- `unified_runtime.dart`: no `class GrpcTransport`, no `grpc`/`dart:io` import, retains `abstract GrpcClient` ✓
- Web-safe file set (excludes native+adapter) analyzes clean WITHOUT `grpc`/`dart:io` ✓

**grpc-code-generation** (verified by `test/transport_native_test.dart` harness):
- `Unified` delegates via `_transport` (no direct `*ServiceClient`) ✓
- `RpcCallOptions.headers` → gRPC `CallOptions.metadata` passthrough ✓
- `GrpcError.notFound` → `NotFoundException` mapping ✓
- Server streaming via `_transport.serverStream` ✓
- Cancel bridge: `RpcCancelToken.onCancel` → `ResponseFuture.cancel()` ✓

**transport-selection** (verified by `web_isolation_test.dart` + factory source):
- Web build excludes `unified_transport_native.dart` + `unified_transport_adapter_*.dart` ✓
- `GrpcTransport` isolated to native conditional-import unit ✓

## Test & Analyze Evidence (fresh)

- `dart test` → **176 passed** (0 failures)
- `dart analyze lib/` → 3 info issues, all PRE-EXISTING (`input_validator.dart` ×2, `runtime_inline_generator.dart` dangling doc comment); **none introduced by this change**
- `dart analyze --fatal-infos` (full) → 23 info issues, all in `test/` files (`prefer_const_constructors`), none in `lib/`, none introduced

## Security

- No hardcoded secrets/keys/tokens in change diff.
- No new `unsafe`/raw-pointer operations (Dart, N/A).

## Spec Drift Handling

`transport-selection/spec.md` used stale `transport_native.dart` naming and
"single file" wording. Aligned to the implemented `unified_transport_*` 5-file
set during this verify (consistent with `web-grpc-build-isolation/spec.md`
alignment done in build phase). This is a verify-phase-allowed spec correction;
no design-doc contradiction remains.

## Branch Handling

Pending user decision (Step 3): local merge / PR / keep / discard.

## Conclusion

All full-verification checks PASS. No CRITICAL or IMPORTANT failures. The change
is ready for archive after branch handling.
