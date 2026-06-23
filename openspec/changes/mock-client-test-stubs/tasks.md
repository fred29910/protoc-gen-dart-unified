## 1. Mock 客户端生成器实现

- [x] 1.1 创建 `lib/src/generators/mock_service_generator.dart`，实现 `MockServiceGenerator` 类，使用 `code_builder` 生成 `@GenerateNiceMocks` 注解的 mock 文件
- [x] 1.2 支持 Unary 方法的 mock 生成（`Future<T>` 返回类型）
- [x] 1.3 支持 Server Streaming 方法的 mock 生成（`Stream<T>` 返回类型）
- [x] 1.4 生成的 mock 文件包含正确的 import（mockito/annotations.dart、pb.dart、service.dart）

## 2. 示例测试生成器实现

- [x] 2.1 创建 `lib/src/generators/example_test_generator.dart`，实现 `ExampleTestGenerator` 类，生成 `*_example_test.dart` 文件
- [x] 2.2 生成的测试文件包含 `main()` + `group('XxxService', ...)` 结构
- [x] 2.3 为每个 Unary 方法生成 `when(...).thenAnswer((_) async => ...)` stub 模板
- [x] 2.4 为每个 Server Streaming 方法生成 `when(...).thenAnswer((_) => Stream.value(...))` stub 模板
- [x] 2.5 生成的测试文件包含正确的 import（test、mock、service、pb.dart）

## 3. 主生成器集成

- [x] 3.1 修改 `lib/src/generator.dart` 的 `CodeGenerator.generate()`，在生成 service 文件后额外调用 `MockServiceGenerator` 和 `ExampleTestGenerator`
- [x] 3.2 新增 `mock` 插件参数解析（默认 `true`），当 `mock=false` 时跳过 mock 和测试文件生成
- [x] 3.3 修改 `bin/protoc_gen_dart_unified.dart` 入口以支持 `mock` 参数传递

## 4. Golden 测试

- [x] 4.1 新增 `test/goldens/user_service_mock.dart.golden` — Mock 文件的期望输出
- [x] 4.2 新增 `test/goldens/user_service_example_test.dart.golden` — 示例测试文件的期望输出
- [x] 4.3 修改 `test/golden/golden_test.dart`，新增 mock 和 example_test 的 golden 测试用例
- [x] 4.4 运行 `UPDATE_GOLDENS=1 dart test test/golden/golden_test.dart` 生成 golden 文件

## 5. 验证与收尾

- [x] 5.1 运行完整测试套件 `dart test`，确保所有测试通过
- [x] 5.2 运行 `dart analyze`，确保零错误
- [x] 5.3 验证生成的 mock 文件可被 `dart analyze` 分析通过
- [x] 5.4 更新 `docs/design.md` Phase 4 状态为已完成
