import 'method_model.dart';

class ServiceModel {
  final String name;
  final List<MethodModel> methods;

  const ServiceModel({
    required this.name,
    required this.methods,
  });
}
