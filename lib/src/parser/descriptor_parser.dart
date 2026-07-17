import 'package:protobuf/protobuf.dart';
// ignore: implementation_imports
import 'package:protoc_plugin/src/gen/google/protobuf/descriptor.pb.dart';
import 'extension_registry.dart';
import 'google/api/annotations.pb.dart';
import 'google/api/http.pb.dart' as http_rule;
import '../model/service_model.dart';
import '../model/method_model.dart';
import '../model/http_rule_model.dart';
import '../model/message_model.dart';
import '../model/field_model.dart';
import '../model/enum_model.dart';

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
            inputType: _stripTypeName(m.inputType),
            outputType: _stripTypeName(m.outputType),
            httpRule: httpRule,
            isServerStreaming: m.serverStreaming,
            isClientStreaming: m.clientStreaming,
          );
        }).toList();
        services.add(
          ServiceModel(
            name: service.name,
            protoFileName: file.name,
            methods: methods,
            messages: messages,
          ),
        );
      }
    }
    return services;
  }

  /// Parses DescriptorProto list into MessageModel list.
  List<MessageModel> _parseMessages(List<DescriptorProto> descriptors) {
    // Build a lookup map from type name to DescriptorProto for map detection.
    final messageMap = <String, DescriptorProto>{
      for (final d in descriptors) d.name: d,
    };

    return descriptors.map((d) {
      // Map oneof index to oneof name.
      final oneofNames = <int, String>{};
      for (var i = 0; i < d.oneofDecl.length; i++) {
        oneofNames[i] = d.oneofDecl[i].name;
      }

      // Parse nested enum types.
      final enums = d.enumType.map((e) {
        return EnumModel(
          name: e.name,
          fullName: '${d.name}.${e.name}',
          values: e.value
              .map((v) => EnumValueModel(name: v.name, number: v.number))
              .toList(),
        );
      }).toList();

      final fields = d.field.map((f) {
        // Extract oneof name if this field belongs to a oneof.
        final oneofName = f.hasOneofIndex() ? oneofNames[f.oneofIndex] : null;

        // Check if this is an enum field.
        final isEnum = f.type == FieldDescriptorProto_Type.TYPE_ENUM;

        // Extract enum value names if enum field.
        List<String>? enumValues;
        if (isEnum) {
          final enumType = d.enumType.firstWhere(
            (e) => '.${d.name}.${e.name}' == f.typeName ||
                e.name == f.typeName.split('.').last,
            orElse: () => EnumDescriptorProto(),
          );
          if (enumType.name.isNotEmpty) {
            enumValues = enumType.value.map((v) => v.name).toList();
          }
        }

        // Extract map key/value types if this field references a map entry.
        String? mapKeyType;
        String? mapValueType;
        final isMap = f.type == FieldDescriptorProto_Type.TYPE_MESSAGE &&
            f.typeName.isNotEmpty;
        if (isMap) {
          final entryName = f.typeName.split('.').last;
          final entryMsg = messageMap[entryName];
          if (entryMsg != null && entryMsg.hasOptions() &&
              entryMsg.options.mapEntry) {
            // This is a genuine map field — extract key/value types.
            for (final entryField in entryMsg.field) {
              if (entryField.name == 'key') {
                mapKeyType = entryField.type.name;
              } else if (entryField.name == 'value') {
                mapValueType = entryField.type.name;
              }
            }
          }
        }

        return FieldModel(
          name: f.name,
          type: f.type.name,
          isRepeated: f.label == FieldDescriptorProto_Label.LABEL_REPEATED,
          isOptional: f.label == FieldDescriptorProto_Label.LABEL_OPTIONAL,
          isMap: isMap,
          messageType: f.typeName,
          oneofName: oneofName,
          isEnum: isEnum,
          enumValues: enumValues,
          mapKeyType: mapKeyType,
          mapValueType: mapValueType,
        );
      }).toList();

      return MessageModel(
        name: d.name,
        fullName: d.name,
        fields: fields,
        enums: enums,
      );
    }).toList();
  }

  /// Extracts HttpRule from method options using ExtensionRegistry re-parse.
  HttpRuleModel? _extractHttpRule(
    MethodDescriptorProto method,
    ExtensionRegistry registry,
  ) {
    if (!method.hasOptions()) return null;

    try {
      final options = MethodOptions();
      options.mergeFromBuffer(method.options.writeToBuffer(), registry);
      final httpRule = options.getExtension(Annotations.http);
      if (httpRule == null) return null;
      return _mapHttpRule(httpRule as http_rule.HttpRule);
    } catch (e) {
      throw StateError(
        'Failed to parse HttpRule for method ${method.name}: $e',
      );
    }
  }

  String _stripTypeName(String typeName) {
    if (typeName.isEmpty) return typeName;
    final parts = typeName.split('.');
    return parts.last;
  }

  /// Maps protobuf HttpRule to internal HttpRuleModel.
  HttpRuleModel _mapHttpRule(http_rule.HttpRule httpRule) {
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
    final responseBody = httpRule.hasResponseBody()
        ? httpRule.responseBody
        : '';

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
