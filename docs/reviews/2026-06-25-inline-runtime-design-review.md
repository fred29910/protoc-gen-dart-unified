# 详细评审：Inline Runtime 设计规格文档

**评审日期：** 2026-06-25
**被评审文档：** docs/superpowers/specs/2026-06-25-inline-runtime-design.md
**评审状态：** 有条件批准（Approve with Revisions）

---

## 总结

这是一个**结构清晰、聚焦明确**的规格文档，解决了一个实际痛点：`protoc_gen_dart_unified` 作为生成工具却泄露为生产依赖。解决方案（将 runtime 内联到 `unified_runtime.dart`）符合代码生成生态的常见模式。

---

## 优点

| 方面 | 评价 |
|------|------|
| **问题陈述清晰** | 用表格量化了泄露的 import 和包依赖，说明了危害 |
| **单文件输出** | 每次调用仅生成一个 `unified_runtime.dart`，避免跨 service 重复 |
| **最小外部依赖** | 仅保留 `dio` —— 正确，因为 HTTP 客户端无法内联 |
| **模板化方案** | Runtime 类型稳定，模板避免了 `code_builder` 的复杂性 |
| **自评审章节** | 体现作者考虑了完整性、范围控制和歧义 |

---

## 关键问题与疑问

### 1. `kIsWeb` 检测 —— 关键实现细节 ⚠️

规格说："Pure Dart can use `bool.fromEnvironment('dart.library.io')` as a fallback"

**风险**：`package:flutter/foundation.dart` 的 `kIsWeb` **在纯 Dart（非 Flutter）项目中不存在**。fallback 应该是主方案，而非备选。

**建议**：在规格中显式定义检测逻辑：

```dart
// 在 unified_runtime.dart 中 —— 任何环境都工作
const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop', defaultValue: false);
// 或者：
const bool _kIsWeb = !bool.fromEnvironment('dart.library.io', defaultValue: true);
```

内部使用 `_kIsWeb`，**不要依赖 Flutter**。

---

### 2. 单文件内的条件编译不可行 ⚠️

规格提到两个 transport 实现 "wrapped in conditional sections" 共存同一文件。**Dart 不支持单文件内的条件代码块**，只支持条件 *import*。

**当前方案无法编译**：
- Native 环境引用 `dart:html` 会报错
- Web 环境引用 `dart:io` 会报错

**解决方案**：
1. **保持条件 import（现有项目模式）**：生成两个文件（`unified_runtime_native.dart`、`unified_runtime_web.dart`）+ 工厂条件 import。这保留了 tree-shaking。
2. **仅当两个分支都不引用平台特定库时** 才能用运行时分支。但 `HttpTransport` native 用 `dart:io` (SSE)，web 用 `dart:html`/`dio` —— **无法共存**。

**结论**：规格的 "单文件 + kIsWeb 分支" **对当前 transport 实现不可行**。需要条件 import → 多文件。

---

### 3. gRPC Transport 未涉及

规格提到："gRPC transport delegates to official `protoc-gen-dart` output"。但 `GrpcTransport`（在 `transport_native.dart`）目前抛出 `UnimplementedError` 并引用 `package:grpc/grpc.dart`。

**问题**：`GrpcTransport` 会内联吗？如果是：
- 会拉入 `package:grpc` —— 用户仍需声明该依赖
- `grpc` 包含原生依赖；内联包装类没问题，但 *依赖* 依然存在

**建议在规格中明确**：是否内联 `GrpcTransport`，若内联则说明 `grpc` 成为用户显式依赖（类似 `dio`）。

---

### 4. 模板维护负担

> "Option 1 is preferred for simplicity — the runtime types are stable and unlikely to change frequently."

**现实检查**：每次修改 runtime 源文件（`transport.dart`、`client_options.dart` 等），**必须同步更新模板**。这是经典的漂移风险。

**缓解方案**：考虑构建时脚本从实际源码提取模板（或反向），至少添加测试验证内联输出能编译且 API 匹配预期。

---

### 5. 版本控制 / 重新生成策略

> "Existing generated files: Must be regenerated with the new plugin version."

**这是对用户的破坏性变更**。用户不能只升级插件 —— 必须重新运行 `protoc`。在发布说明/迁移指南中明确记录。考虑在 `unified_runtime.dart` 加版本标记：

```dart
// GENERATED_BY: protoc-gen-dart-unified@0.2.0
```

便于排查陈旧生成代码。

---

### 6. 拦截器链 —— 生成代码 vs Runtime

规格说拦截器（`RetryInterceptor`、`TracingInterceptor` 等）进 `unified_runtime.dart`。但 **用户自定义拦截器** 在其业务代码中定义，通过 `ClientOptions` 传入。

**验证**：内联 `RpcInterceptor` 抽象类和内置实现，用户拦截器从 `unified_runtime.dart` 导入 `RpcInterceptor`。这可行 —— 只需确保抽象类 API 稳定。

---

### 7. Golden Test 更新量大

> "Golden tests and integration tests will need their expected output updated"

这是**大量机械改动**。规划：
- 批量更新 golden 文件的脚本，或
- 在规格中记录 `UPDATE_GOLDENS=1` 工作流

---

## 规格修订建议

| 章节 | 修改建议 |
|------|----------|
| **Platform Handling** | 替换 `kIsWeb` 单文件方案为条件 import（2 文件），沿用现有 `transport_native.dart` / `transport_web.dart` 模式 |
| **gRPC Transport** | 明确："GrpcTransport 内联；使用 gRPC 的用户需声明 `grpc` 依赖" |
| **Template Strategy** | 增加："模板真实来源 = `lib/src/runtime/` 文件。构建脚本 `tool/update_runtime_template.dart` 将源码同步到生成器模板" |
| **Breaking Change** | 增加迁移指南："用户必须重新运行 protoc；从 pubspec.yaml 移除 `protoc_gen_dart_unified`" |
| **Verification** | 增加："集成测试：生成代码 → `dart analyze` → `dart pub get` → 在全新 Dart 项目编译通过" |

---

## 整体评估

| 维度 | 评分 | 说明 |
|------|------|------|
| **清晰度** | ★★★★★ | 结构优秀，表格/对比图完整 |
| **可行性** | ★★★☆☆ | `kIsWeb` 单文件方案需修订（需要条件 import） |
| **完整性** | ★★★★☆ | 缺 gRPC transport 细节、模板同步机制 |
| **风险** | 中等 | 模板漂移、破坏性变更沟通 |

---

## 建议

**有条件批准** —— 核心思路正确且高价值。主要修正平台检测/条件 import 技术方案，再进入实现。
