import 'method_model.dart';
import 'message_model.dart';

class ServiceModel {
  final String name;
  final List<MethodModel> methods;
  final List<MessageModel> messages;

  const ServiceModel({
    required this.name,
    required this.methods,
    this.messages = const [],
  });
}
