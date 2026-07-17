# SDD Progress: Web gRPC Isolation

Plan: docs/superpowers/plans/2026-07-16-web-grpc-isolation.md
Change: web-grpc-isolation
Started: 2026-07-16
Review mode: thorough (batched review every ≤3 tasks + final full review, max 2 fix rounds each)
TDD: tdd (RED/GREEN evidence required per task)

## Decisions (confirmed with user)
- 方案 A → **A1**：单文件 `unified_runtime.dart` 改为 5 文件条件导入集合
  （unified_runtime + unified_transport_{factory,native,web,stub}）。
- 适配器形态 **O-C**：全局 `unified_transport_native.dart` 无参（通用 GrpcTransport
  + createTransport + _mapGrpcError + cancel 桥接）；**新增 per-service**
  `unified_transport_adapter_{service}.dart`（逐方法 switch 分发到真实 *ServiceClient，
  native-only，携带唯一 pbgrpc import）。

## Tasks

### Group 1: Generator changes (tasks 1.1-1.5) — DONE
- [x] 1.1 service_generator._buildDirectives — remove pbgrpc import branch (commits 36561aa, 99d6281)
- [x] 1.2 service_generator._buildUnifiedImpl — remove _grpcClient field + grpcClient ctor param (dfeba04)
- [x] 1.3 service_generator._buildGrpcUnaryCall — use _transport.unaryCall (6463f50)
- [x] 1.4 service_generator._buildGrpcServerStreamBody — use _transport.serverStream (1af9b15)
- [x] 1.5 service_generator._buildApiSdk — grpcClient: GrpcClient? → createTransport, Unified 2-arg ctor (2723015; 165 green)

### Group 2: Runtime template isolation (A1: 5-file conditional-import set) — DONE
- [x] 2.1 runtime_inline_generator.generate() — strip GrpcTransport + inline createTransport, re-export factory; keep abstract GrpcClient + Protocol (60408e8)
- [x] 2.2 add generateTransportFactory/Native/Web/Stub (60408e8)
- [x] 2.3 generator_registry — register 4 global transport generators → 5 runtime files/request (385f235)
- [x] 2.4 tests — golden + integration + registry + grpc_transport assertions updated for 5 files (16b7ebb, 5711f4b, 33d9446)
- [x] Batch 2 review — SPEC_COMPLIANCE PASS, CODE_QUALITY APPROVED (known: adapter stub unwired, design A→A1 drift, web files content-only)

### Group 3: per-service adapter (O-C) — DONE
- [x] 3.1 runtime_inline_generator.generateTransportNative() — add _mapGrpcError + cancel bridge (9a66309)
- [x] 3.2 runtime_inline_generator.generateTransportAdapter(ServiceModel) — NEW per-service adapter (9a66309)
- [x] 3.3 generator_registry — TransportAdapter perService generator (6d4a40c)
- [x] 3.4 tests — file-count assertions updated (7/9); 172 green
- [x] Batch 3 review — factory conditional-import "duplicate symbol" concern = FALSE POSITIVE
  (single import with if-clauses selects ONE target, mutually exclusive; confirmed by
  `dart analyze lib/src/runtime/transport_factory.dart` = clean). Genuine Minor gap
  found: per-service adapter was only string-asserted, never compiled → closed by
  `generateTransportAdapter() compiles against stub pbgrpc` test (690ae00).

### Group 4: Web isolation verification + docs — IN PROGRESS
- [x] 4.1 test/web_isolation_test.dart — compile-level web proof: web-safe file set
  (excludes native+adapter) analyzes clean WITHOUT grpc/dart:io; no non-native file
  imports grpc/dart:io/pbgrpc (690ae00; 175 green total)
- [x] 4.2 design doc sync — §1/§2/§7 updated A→A1 + O-C decisions (this commit)
- [ ] 4.3 docs/usage.md — web pure-gRPC unsupported + regeneration migration note
- [ ] 4.4 final full review (thorough) before archive

## Batched review checkpoints
- [x] Batch 1 — after 1.5 (Group 1): SPEC_COMPLIANCE PASS, CODE_QUALITY APPROVED
- [x] Batch 2 — after 2.4 (Group 2): SPEC_COMPLIANCE PASS, CODE_QUALITY APPROVED
- [x] Batch 3 — after 3.4 (Group 3): concern resolved as false-positive; Minor gap closed
- [ ] Final full review — after 4.4 (all tasks)

## Test status
- Full suite: 175 green (was 165 at Group 1 → +10 across Groups 2-4)
- `dart analyze lib/` — 3 pre-existing info issues only (input_validator.dart ×2,
  runtime_inline_generator.dart dangling doc comment); NO new issues from this change.
- `dart analyze --fatal-infos` (full) — 23 info issues, all in test/ files
  (pre-existing prefer_const_constructors), none in lib/, none introduced.

## Open / deferred
- docs/usage.md migration note (4.3) — non-blocking for functionality
- design doc §Non-Goal still references single-file concept — superseded by §1 note
