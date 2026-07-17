# Tasks: post-review-fixes-and-optimization

> **Scope reduction (2026-07-17)**: This change was opened 2026-06-26 against base
> `b65d04e`. Since then 43 commits / 97 files (+8854 lines) landed via other changes.
> Tasks 1–5 and 8 were independently implemented and **archived** through separate,
> more focused changes. Their capabilities are now present in main specs:
> - Task 1 (model oneof/enum/map) → `oneof-field-support`, `enum-type-mapping`, `map-type-detection`
> - Task 2 (parser oneof/enum/map) → same 3 specs above
> - Task 3 (gRPC type safety) → `type-safe-grpc-client`
> - Task 4 (input validation) → `input-validation`
> - Task 5 (generator registry) → `code-generation-pipeline`
> - Task 8 (tests) → covered by `test/parser/*`, `test/model/enum_model_test.dart`, `test/runtime/grpc_client_test.dart`, golden harness
>
> **Remaining net-new scope: Task 6 (runtime inline extraction) and Task 7 (exception hierarchy) only.**
> These two were never implemented by any other change and remain un-duplicated.

## 1–5, 8. Superseded by archived changes (COMPLETED, no build needed)

- [x] 1.1–1.4 Model layer (oneof/enum/map fields) — shipped via `oneof-field-support`, `enum-type-mapping`, `map-type-detection`
- [x] 2.1–2.5 Parser enhancements — shipped via same 3 specs
- [x] 3.1–3.3 gRPC type safety (`dynamic` → `Object?`, streaming) — shipped via `type-safe-grpc-client`
- [x] 4.1–4.5 Input validation (`input_validator.dart`) — shipped via `input-validation`
- [x] 5.1–5.4 Generator registry + parallel generation — shipped via `code-generation-pipeline`
- [x] 8.1–8.7 Tests + golden updates — covered by existing test suite

## 6. 运行时代码提取（Runtime Extraction）— REMAINING

- [ ] 6.1 `RuntimeInlineGenerator`：将内联字符串模板提取到 `lib/src/runtime/inline/` 目录中的独立文件
- [ ] 6.2 添加版本号同步机制，确保生成器版本与运行时版本一致

## 7. 错误报告改进（Error Reporting）— REMAINING

- [ ] 7.1 创建 `GenerationException` 密封类层次结构（ParseException/ValidationException/InternalException）
- [ ] 7.2 `generator.dart`：按异常类型分类错误信息，附带文件/行号/模块上下文
- [ ] 7.3 `descriptor_parser.dart`：将 `StateError` 替换为精确异常类型
