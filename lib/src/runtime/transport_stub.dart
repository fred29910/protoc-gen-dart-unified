import 'transport.dart';
import 'grpc_client.dart';

Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
}) => null;
