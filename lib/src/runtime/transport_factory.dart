import 'transport.dart';
import 'transport_stub.dart'
    if (dart.library.io) 'transport_native.dart'
    if (dart.library.js_interop) 'transport_web.dart' as impl;

Transport? createTransport(String endpoint) => impl.createTransport(endpoint);
