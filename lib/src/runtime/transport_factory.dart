import 'transport.dart';
import 'grpc_client.dart';
import 'transport_stub.dart'
    if (dart.library.io) 'transport_native.dart'
    if (dart.library.js_interop) 'transport_web.dart'
    as impl;

Transport? createTransport(
  String endpoint, {
  GrpcClient? grpcClient,
  List<RpcInterceptor> interceptors = const [],
}) => impl.createTransport(
  endpoint,
  grpcClient: grpcClient,
  interceptors: interceptors,
);
