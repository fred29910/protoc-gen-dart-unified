import 'package:protobuf/protobuf.dart';
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'extension_registry.dart';
import 'google/api/annotations.pb.dart';
import '../model/service_model.dart';
import '../model/method_model.dart';
import '../model/http_rule_model.dart';
import '../model/message_model.dart';
import '../model/field_model.dart';

class DescriptorParser {
  List<ServiceModel> parse(List<FileDescriptorProto> files) {
    final registry = createHttpExtensionRegistry();
    final services = <ServiceModel>[];
    for (final file in files) {
      // Parse all messages in this file
      final messages = _parseMessages(file.messageType);
      for (final service in file.service) {
        final methods = service.method.map((m) {
          final httpRule = _extractHttpRule(m, registry);
          return MethodModel(
            name: m.name,
            inputType: m.inputType,
            outputType: m.outputType,
            httpRule: httpRule,
            isServerStreaming: m.serverStreaming,
            isClientStreaming: m.clientStreaming,
          );
        }).toList();
        services.add(ServiceModel(
          name: service.name,
          methods: methods,
          messages: messages,
        ));
      }
    }
    return services;
  }

  /// Parses DescriptorProto list into MessageModel list.
  List<MessageModel> _parseMessages(List<DescriptorProto> descriptors) {
    return descriptors.map((d) {
      final fields = d.field.map((f) {
        return FieldModel(
          name: f.name,
          type: f.type.name,
          isRepeated: f.label == FieldDescriptorProto_Label.LABEL_REPEATED,
          isMap: f.type == FieldDescriptorProto_Type.TYPE_MESSAGE &&
              f.typeName.isNotEmpty,
          messageType: f.typeName,
        );
      }).toList();
      return MessageModel(
        name: d.name,
        fullName: d.name,
        fields: fields,
      );
    }).toList();
  }

  /// Extracts HttpRule from method options using ExtensionRegistry re-parse.
  HttpRuleModel? _extractHttpRule(
      MethodDescriptorProto method, ExtensionRegistry registry) {
    if (!method.hasOptions()) return null;

    try {
      final options = MethodOptions();
      options.mergeFromBuffer(
          method.options.writeToBuffer(), registry);
      final httpRule = options.getExtension(Annotations.http);
      if (httpRule == null) return null;
      return _mapHttpRule(httpRule);
    } catch (_) {
      return null;
    }
  }

  /// Maps protobuf HttpRule to internal HttpRuleModel.
  HttpRuleModel _mapHttpRule(dynamic httpRule) {
    String kind = '';
    String path = '';

    // HttpRule has a oneof pattern field
    if (httpRule.hasGet()) {
      kind = 'get';
      path = httpRule.get;
    } else if (httpRule.hasPut()) {
      kind = 'put';
      path = httpRule.put;
    } else if (httpRule.hasPost()) {
      kind = 'post';
      path = httpRule.post;
    } else if (httpRule.hasDelete()) {
      kind = 'delete';
      path = httpRule.delete;
    } else if (httpRule.hasPatch()) {
      kind = 'patch';
      path = httpRule.patch;
    } else if (httpRule.hasCustom()) {
      kind = 'custom';
      path = httpRule.custom;
    }

    final body = httpRule.hasBody() ? httpRule.body : '';
    final responseBody =
        httpRule.hasResponseBody() ? httpRule.responseBody : '';

    final additionalBindings = httpRule.additionalBindings
        .map<HttpRuleModel>((b) => _mapHttpRule(b))
        .toList();

    return HttpRuleModel(
      kind: kind,
      path: path,
      body: body,
      responseBody: responseBody,
      additionalBindings: additionalBindings,
    );
  }
}
