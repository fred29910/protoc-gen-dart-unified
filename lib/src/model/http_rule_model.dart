/// Represents the HTTP rule mapping for a gRPC method.
class HttpRuleModel {
  final String kind; // get, post, put, patch, delete
  final String path;
  final String body;
  final String responseBody;
  final List<HttpRuleModel> additionalBindings;

  const HttpRuleModel({
    required this.kind,
    required this.path,
    this.body = '',
    this.responseBody = '',
    this.additionalBindings = const [],
  });
}
