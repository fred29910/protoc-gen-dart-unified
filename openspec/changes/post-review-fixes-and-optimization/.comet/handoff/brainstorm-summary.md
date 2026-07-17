# Brainstorm Summary

- Change: post-review-fixes-and-optimization
- Date: 2026-06-26

## 确认的技术方案

### 1. Parser 层增强
- **oneof**: 提取 `oneof_decl`/`oneof_index` → `FieldModel.oneofName (String?)`，在抽象接口层生成 sealed class 分组模式
- **enum**: 提取 `EnumDescriptorProto` → `EnumModel`，生成代码中直接引用 `pb.dart` 的 Dart enum 类型
- **map**: 双层检测（type=TYPE_MESSAGE + entry message 含 key/value 字段）→ `mapKeyType`/`mapValueType`

### 2. GrpcClient 类型安全
- 引入 `abstract class GrpcClient` 泛型接口（`unaryCall<T>()`/`serverStream<T>()`）
- 生成的 `Unified<Service>` 使用 `GrpcClient` 替代 `dynamic`

### 3. 输入验证与错误分层
- 新增 `InputValidator` 作为解析前置步骤
- `sealed class GenerationException` 层次（Parse/Validation/Internal）

### 4. 生成器注册表与并行管道
- `Map<String, Generator>` 注册表替代硬编码调度
- 可选 `Isolate.run()` 并行生成
- 增量输出降低峰值内存

## 关键取舍与风险

| 决策 | 取舍 | 风险 |
|------|------|------|
| GrpcClient 接口 | 需要用户传递适配器 vs 当前自动创建 | 破坏现有 API 兼容性（需要迁移指南） |
| sealed class oneof | 更安全的类型匹配 vs 更多生成代码 | 需 Dart 3.0+ 支持 |
| 可选并行 | 速度 vs 复杂度 | Isolate context 传输开销 |

## 测试策略

- 单元测试覆盖每个扩展点
- Golden 测试覆盖含 oneof/enum/map 的生成输出
- 编译验证确保生成代码可编译

## Spec Patch

需回写：`input-validation/spec.md` — 新增 MODIFIED Requirements 节（补充错误信息粒度需求）
