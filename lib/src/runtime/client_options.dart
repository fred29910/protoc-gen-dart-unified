import 'protocol.dart';

class ClientOptions {
  final String endpoint;
  final Protocol protocol;
  final Duration? timeout;

  const ClientOptions({
    required this.endpoint,
    this.protocol = Protocol.auto,
    this.timeout,
  });
}
