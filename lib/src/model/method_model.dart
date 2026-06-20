import 'http_rule_model.dart';

class MethodModel {
  final String name;
  final String inputType;
  final String outputType;
  final HttpRuleModel? httpRule;

  const MethodModel({
    required this.name,
    required this.inputType,
    required this.outputType,
    this.httpRule,
  });
}
