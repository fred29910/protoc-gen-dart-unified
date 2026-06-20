import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';

class DescriptorParser {
  List<ServiceModel> parse(List<FileDescriptorProto> files) {
    final services = <ServiceModel>[];
    for (final file in files) {
      for (final service in file.service) {
        final methods = service.method.map((m) {
          // TODO(Task 3): Add ExtensionRegistry http rule extraction
          return MethodModel(
            name: m.name,
            inputType: m.inputType,
            outputType: m.outputType,
            httpRule: null,
          );
        }).toList();
        services.add(ServiceModel(name: service.name, methods: methods));
      }
    }
    return services;
  }
}
