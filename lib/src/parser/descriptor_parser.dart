import 'package:protobuf/protobuf.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'extension_registry.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';
import '../model/http_rule_model.dart';

class DescriptorParser {
  List<ServiceModel> parse(List<FileDescriptorProto> files) {
    final registry = createHttpExtensionRegistry();
    final services = <ServiceModel>[];
    for (final file in files) {
      for (final service in file.service) {
        final methods = service.method.map((m) {
          final httpRule = _extractHttpRule(m, registry);
          return MethodModel(
            name: m.name,
            inputType: m.inputType,
            outputType: m.outputType,
            httpRule: httpRule,
          );
        }).toList();
        services.add(ServiceModel(name: service.name, methods: methods));
      }
    }
    return services;
  }

  HttpRuleModel? _extractHttpRule(MethodDescriptorProto method, ExtensionRegistry registry) {
    // TODO(Task 3.2): Implement MethodOptions re-parse with registry
    // 1. Get method.options bytes
    // 2. Re-parse with mergeFromBuffer(bytes, registry)
    // 3. getExtension(Annotations.http) to extract HttpRule
    // 4. Map HttpRule to HttpRuleModel
    return null; // placeholder
  }
}
