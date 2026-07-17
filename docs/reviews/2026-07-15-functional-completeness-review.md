# 功能完整度评审报告 · protoc-gen-dart-unified

**评审日期**：2026-07-15
**评审分支**：`feature/20260626/post-review-fixes-and-optimization`
**评审依据**：`openspec/specs`（21 个主规格）+ `openspec/changes/*/specs`（mock/example）+ `docs/superpowers/specs`（5 份技术设计）+ `docs/reviews/*`
**验证手段**：逐文件比对 `lib/src` 实现；运行 `dart test`（**158 passed**）、`dart analyze --fatal-infos`（**0 error / 0 warning / 14 info**）

---

## 1. 评审结论（Executive Summary）

| 维度 | 评价 |
|------|------|
| **整体功能完整度** | **≈ 60%**（约 10 个 spec 完全满足，9 个部分满足，2 个严重缺失） |
| **HTTP 传输** | ★★★★★ 路径/查询/请求体/错误映射/拦截器链均已实现并通过测试 |
| **服务治理与可观测** | ★★★★★ 重试/追踪/取消/超时/`withRetry`/SSE/异常层级完整 |
| **gRPC 传输** | ☠️ **完全不可用**——生成代码静默走 HTTP，未委托 `*ServiceClient` |
| **测试覆盖** | ⚠️ 全绿但**只覆盖 HTTP 路径**，gRPC 分支零测试，掩盖 P0 缺陷 |
| **代码质量** | ★★★★☆ 零 error/warning，14 条 `prefer_const_constructors` info |

**核心结论**：项目在 **HTTP 单传输 + 服务治理** 方向已生产可用；但**作为"HTTP/gRPC 双传输统一 SDK 生成器"的核心卖点严重缺失**——gRPC 委托链路从未接通。测试全绿是**误导性信号**，因为唯一 fixture（`test/fixtures/user.proto`）的全部方法都带 `google.api.http` 注解，`_useHttp=true`，使 gRPC 代码路径（`isGrpc=true`）**从未被任何测试执行**。

---

## 2. 功能完整度矩阵

状态图例：✅ 满足 / ⚠️ 部分满足 / ❌ 未满足 / ➖ 不适用

| # | Spec（主树） | 状态 | 说明 |
|---|--------------|------|------|
| 1 | dart-generator-scaffold | ✅ | 插件入口、Descriptor 遍历、文件命名稳定 |
| 2 | google-api-http-extraction | ✅ | ExtensionRegistry + MethodOptions re-parse |
| 3 | google-api-http-parser | ✅ | HttpRuleModel 全字段 + additional_bindings |
| 4 | http-code-generation | ✅ | 路径插值/查询扁平/请求体/`code_builder`/一元/流式/错误映射/按服务选传输 **均已实现并测试** |
| 5 | unary-service-generation | ✅ | Facade + 路径/查询 |
| 6 | unary-service-generation-delta | ⚠️ | HTTP 调用 ✅；**gRPC 委托 ❌**；错误处理 ✅；code_builder ✅ |
| 7 | runtime-contract | ✅ | Protocol/ClientOptions/Transport/RpcInterceptor/ApiException |
| 8 | sdk-entry-generation | ⚠️ | ApiSdk ✅；**Protocol.auto 路由 ❌**；拦截器链 ✅ |
| 9 | service-governance-observability | ✅ | 拦截器/取消令牌/超时/重试/jitter/Traceparent/`withRetry`/SSE/异常层级（仅 `RpcInterceptor` 签名用 `InterceptorContext` 包裹，与 spec 字面"独立参数"有偏差，但与设计文档一致） |
| 10 | transport-implementation | ⚠️ | HttpTransport ✅；**GrpcTransport ❌**（生成运行时排除，且 `createTransport` 永不返回）；HTTP SSE native ✅ / web `throw UnimplementedError` |
| 11 | transport-selection | ⚠️ | 条件导入平台选择 ✅；**Protocol.auto 自适应路由 ❌**（`createTransport` 忽略 `protocol`，恒返 HTTP） |
| 12 | unified-error-mapping | ✅ | 17 个 gRPC 规范码映射 + 异常层级 |
| 13 | grpc-code-generation | ❌ | **gRPC 委托、`*ServiceClient` 元数据透传、gRPC 错误映射、gRPC server streaming 全部未接通** |
| 14 | type-safe-grpc-client | ⚠️ | `GrpcClient` 抽象接口 ✅；HTTP-only 不生成 `_grpcClient` ✅；**但无适配器实现、未接入 `_grpcClient` 且生成代码仍用 `_transport`（HTTP）** |
| 15 | enum-type-mapping | ⚠️ | 解析 ✅（`FieldModel.isEnum`/`enumValues`）；**`EnumModel.dartName` 从未计算；未生成任何 Dart enum 代码** |
| 16 | oneof-field-support | ⚠️ | `oneofName` 解析 ✅；**`oneofName` 解析后从未在生成中使用**（oneof 语义依赖整消息序列化透传，未生成专属逻辑） |
| 17 | map-type-detection | ✅ | 用 `options.mapEntry` 精确判定（优于 spec 字面"检查 key/value 字段"），键值类型已提取 |
| 18 | input-validation | ⚠️ | 空服务/空方法/服务名空/方法重名(case-sensitive) ✅；**缺 case-insensitive 重名检测、类型存在性检测、保留字冲突检测** |
| 19 | code-generation-pipeline | ⚠️ | 注册表 ✅；并发安全验证 ✅；**并行生成 ❌（串行循环）、流式输出 ❌（全内存）** |
| 20 | golden-test-harness | ✅ | fixture/golden/自定义选项/格式化幂等 |
| 21 | golden-test-harness-delta | ⚠️ | 全对比 ✅、ExtensionRegistry ✅、HttpMapper ✅；**spec 写"`--update-goldens` flag"，实为实现 `UPDATE_GOLDENS=1` 环境变量（措辞不符）** |

**变更内 specs（未归档）**：
| spec | 状态 | 说明 |
|------|------|------|
| mock-client-generation | ✅ | 实现完整，匹配 spec；但 change 未归档、spec 未并入主树 |
| example-test-stub-generation | ✅ | 同上 |

---

## 3. 关键缺陷（P0）

### 3.1 gRPC 传输链路彻底断开（最严重）
**证据链**：
- `runtime/native/transport_native.dart` 与 `transport_web.dart` 的 `createTransport` 均**忽略 `grpcClient` 参数，恒返 `HttpTransport`**。
- `runtime_inline_generator.dart:613-619` 生成的 `unified_runtime.dart` 同样 `createTransport` 忽略 `grpcClient`。
- `service_generator.dart:_buildGrpcUnaryCall` / `_buildGrpcServerStreamBody` 生成的 gRPC 方法体使用 **`_transport.unaryCall(...)`**，而 `_transport` 实际是 `HttpTransport`——**生成代码从不调用 `_grpcClient`**（后者被声明为 `GrpcClient` 字段却**零引用**）。
- 没有任何适配器将生成的 `*ServiceClient`（来自 `*.pbgrpc.dart`）包装为 `GrpcClient`；`ApiSdk` 中 `grpcClient` 默认 `null`。

**后果**：对 gRPC-only 服务，生成代码会在运行时向 `/Service/method` 发起 **POST HTTP 请求**（而非 gRPC），并试图把 JSON 响应 `as` 成 protobuf 消息——必然失败。这与 `AGENTS.md`（"gRPC transport delegates to official protoc-gen-dart output"）、`grpc-code-generation`、`transport-implementation`、`unary-service-generation-delta` 的 gRPC fallback 场景**直接矛盾**。

### 3.2 测试覆盖盲区掩盖 3.1
唯一 fixture `test/fixtures/user.proto` 的所有方法都带 `google.api.http`，故 `isGrpc` 恒为 `false`。**没有任何 gRPC-only fixture / 集成测试 / golden 文件**验证 gRPC 委托路径。158 个测试全绿，但 gRPC 分支处于"编译通过、运行即错"状态。

---

## 4. 主要缺口（P1）

| 缺口 | 关联 spec | 现状 |
|------|-----------|------|
| **Protocol.auto 自适应路由** | sdk-entry-generation / transport-selection | `createTransport` 完全忽略 `protocol`，Native 永不返回 gRPC；`Protocol.grpc` 枚举值形同虚设 |
| **嵌套消息深度解析** | map/oneof/enum（解析层） | `_parseMessages` 仅解析 `file.messageType`（顶层）。嵌套消息未解析 → 引用嵌套类型的方法签名/字段映射会断链（review 已标记 `fix/nested-message-parsing` HIGH） |
| **并行生成 / 流式输出** | code-generation-pipeline | `GeneratorRegistry.generateForService` 串行迭代；全部文件存内存后返回。spec 的"并行生成""流式输出"两条 requirement 未满足（review 称 M3/M4 未在 scope） |
| **enum 代码生成缺失** | enum-type-mapping | `EnumModel` 已解析但 `dartName` 从未赋值，`ServiceGenerator` 完全不引用 `message.enums`，**不产出任何 Dart enum 类型**（spec 明确要求"generate a valid Dart enum type"） |
| **oneof 未利用** | oneof-field-support | `oneofName` 提取后未在生成中使用；未生成 oneof 专属序列化/切换逻辑 |
| **输入验证不完整** | input-validation | 缺（a）case-insensitive 方法重名（spec 明确要求，当前为大小写敏感）、（b）输入/输出类型存在性、（c）Dart 保留字冲突 |
| **error-handling 能力无 spec** | post-review 提案"Modified Capabilities" | 提案列出 `error-handling` 能力，但主树无 spec；`GenerationException` 密封类（tasks 7.1-7.3）未实现，生成器仍为 catch-all `'Generation failed: $e'` |

---

## 5. 已验证 / 已修复项（对照 6-26 review 报告）

| review 关注点 | 当前状态 |
|---------------|----------|
| HTTP REST 路径真正生成（CRITICAL #2 `feat/http-transcoding-wiring`） | ✅ **已解决**：`RpcCallOptions` 的 `httpPath/httpMethod/httpQueryParams/httpBody` 在 `HttpTransport._rawUnaryCall` 中被真实消费 |
| `kIsWeb` 平台兼容（HIGH `fix/kisweb-compat`） | ✅ **已解决**：采用 `dart.library.io` / `dart.library.js_interop` 条件导入（非 `kIsWeb`），符合设计文档 |
| 格式失败静默（MEDIUM `fix/formatter-hard-error`） | ✅ **已解决**：`DartFormatter.format` 在 `CodeGenerator.generate()` 的 try/catch 中被捕获并回显错误（非静默，仅信息粒度可优化） |
| gRPC 客户端类型安全（H1） | ⚠️ 部分：引入 `GrpcClient` 接口、消除 `dynamic`，但**无实现/无接线** |
| oneof/enum/map（H2/H3/H4） | ⚠️ 解析层完成，生成与测试层未完成 |
| 输入验证（H5） | ⚠️ 部分（见 4） |
| 生成器注册表（M2） | ✅ 已实现并测试 |
| 服务治理（重试/追踪/取消/超时/SSE/异常层级/`withRetry`） | ✅ 完整且多维度测试覆盖 |

---

## 6. OpenSpec 流程状态问题

1. **`post-review-fixes-and-optimization` change**：`tasks.md` 中 8 个章节任务**全部未勾选 `[ ]`**，但代码与 6-26 review 报告（151/151, A-）一致表明已实现。任务状态与代码事实脱节。
2. **`mock-client-test-stubs` change**：`tasks.md` 全部 `[x]`，但 change **未归档**，`specs/` 未并入 `openspec/specs/` 主树 → 能力已实现但无主树 spec。
3. **`error-handling`** 作为提案的 Modified Capability，既无主树 spec、也无实现。
4. 主树存在 `code-generation-pipeline` spec（含并行/流式 requirement），但其对应 change 未归档，且两项 requirement 未实现——**主树 spec 与实现不一致**。

---

## 7. 优先级修复清单（建议）

**P0（阻塞交付）**
1. 接通 gRPC 委托：实现 `*ServiceClient` → `GrpcClient` 适配器，由 `ApiSdk`/`createTransport` 装配；生成 gRPC 方法体改为调用 `_grpcClient.unaryCall/serverStream`；`createTransport` 按 `Protocol` 返回 `GrpcTransport`（需把 `GrpcTransport` 纳入生成运行时）。
2. 补充 gRPC-only fixture + 集成测试 + golden，覆盖 `_useHttp=false` 全路径，消除测试盲区。

**P1（高优先级）**
3. `Protocol.auto` / `transport-selection` 路由：Native 按 `protocol`/`grpc` 返回 gRPC 传输。
4. 嵌套消息递归解析（`fix/nested-message-parsing`）。
5. enum：计算 `dartName` 并生成 Dart enum 类型代码（或明确声明委托 protoc-gen-dart 并在 spec 注明）。
6. input-validation：补 case-insensitive 重名、类型存在性、保留字检测。
7. code-generation-pipeline：并行/流式（或下调 spec requirement 以匹配 scope）。

**P2（规范与流程）**
8. oneof：在生成/文档中落实 oneof 语义（当前依赖整消息透传，需显式验证）。
9. 归档 `mock-client-test-stubs`、`post-review-fixes-and-optimization` change，将 specs 并入主树；补齐 `error-handling` spec 或自提案移除。
10. 勾选 `post-review-fixes-and-optimization/tasks.md` 已完成的条目。
11. 统一 golden 更新机制命名（spec 写 `--update-goldens` flag，实现为 `UPDATE_GOLDENS` env）。

---

**附：整体评级 A-（架构与设计优秀，但 gRPC 双传输核心能力缺失，测试绿灯存在误导）——在当前状态下，项目仅对"纯 HTTP 传输"场景生产可用。**
