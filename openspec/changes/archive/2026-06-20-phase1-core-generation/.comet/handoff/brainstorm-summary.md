# Brainstorm Summary

- Change: phase1-core-generation
- Date: 2026-06-20

## 确认的技术方案

### 1. Vendored google/api protos（方案 A）
- 用系统 protoc + 官方 protoc-gen-dart 预生成 `google/api/http.pb.dart` 和 `google/api/annotations.pb.dart`
- 提交到 `lib/src/parser/google/api/` 目录
- 稳定，零运行时依赖

### 2. code_builder + DartFormatter（方案 A）
- code_builder 生成 AST → DartEmitter 输出字符串 → `DartFormatter(languageVersion: Version(3,10,0))` 二次格式化
- 保证产物与 `dart format` 完全一致

### 3. Transport 委托设计
- 生成的 facade 方法名与 proto 方法名一致
- `GrpcTransport.unaryCall(serviceName, methodName, request)` 内部通过 serviceName+methodName 路由到对应 `*ServiceClient`
- HttpTransport 完整实现（dio），serverStream 抛 UnimplementedError
- GrpcTransport serverStream 委托原生 `ResponseStream`

### 4. MessageModel 完整解析（方案 A）
- 解析 `DescriptorProto` 获取完整 field 列表（含嵌套 message）
- 支持 query 展平的 dot-notation

### 5. 单文件生成模式
- 每个 service 生成一个 `<service>_service.dart` 文件
- 包含：abstract class + UnifiedServiceImpl + ApiSdk 入口，全部在一个文件里

### 6. Generator 协调架构（方案 B）
- 每 service 统一选择 transport：如果 service 有任何方法带 `google.api.http`，整个 service 用 HttpGenerator；否则用 GrpcGenerator
- 一个 service 只依赖一种 transport，生成代码更简单
- HttpGenerator 对没有 http annotation 的方法生成抛 `UnsupportedError`

## 关键取舍与风险

| 决策 | 取舍 | 风险 |
|------|------|------|
| Vendored protos | 稳定但需手动维护 | proto 版本升级时需重新生成 |
| 每 service 统一 transport | 简单但不够灵活 | 混合 annotation 的 service 无法部分走 HTTP |
| 完整 MessageModel | 工作量大 | 嵌套 message 解析复杂 |
| code_builder | AST 安全但代码量多 | 学习曲线 |

## 测试策略

| 测试类型 | 覆盖 |
|----------|------|
| 单元 | HttpMapper（路径插值、Query 展平、Body 映射） |
| 单元 | ExtensionRegistry 提取（真实 proto bytes） |
| 单元 | DescriptorParser（service/method/message 遍历） |
| 集成 | CodeGenerator 端到端（request → response → 可编译 Dart） |
| Golden | user.proto → user_service.dart 完整对比 |
| 运行时 | Transport 工厂、ApiException 映射（扩展已有测试） |

## Spec Patch

- `http-code-generation` spec：补充 "service-level transport selection" 场景
- `unary-service-generation-delta` spec：补充 "无 http annotation 时 gRPC fallback" 场景
