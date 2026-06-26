# Runtime Transport Layer

**Generated:** 2026-06-26
**Parent:** `AGENTS.md` (root)

## OVERVIEW

HTTP + gRPC transport runtime for generated unified SDKs — 19 files implementing transport, interceptor chain, SSE parsing, cancellation, and auth.

## STRUCTURE

```
runtime/
├── transport*.dart          # Abstract Transport + native/web/stub/factory
├── {auth,retry,tracing,logging}_interceptor.dart  # Interceptor implementations
├── client_options.dart      # ClientOptions + buildInterceptorChain()
├── rpc_{call_options,cancel_token,interceptor}.dart  # Per-call primitives
├── sse_parser.dart          # Server-Sent Events parser
├── api_exception.dart       # ApiException
├── http_status_mapping.dart # HTTP status → exception mapping
├── retry_policy.dart        # RetryPolicy config
├── protocol.dart            # Protocol enum (auto/http/grpc)
└── with_retry.dart          # Retry utility
```

## WHERE TO LOOK

| Concept | File | Notes |
|---------|------|-------|
| Transport abstraction | `transport.dart` | unaryCall + serverStream + executeWithInterceptors |
| Native HTTP client | `transport_native.dart` | Dio-based, 290 lines, SSE via dio ResponseType.stream |
| Web HTTP client | `transport_web.dart` | http package, conditional import |
| Interceptor chain building | `client_options.dart` | tracing → user → retry order |
| SSE parsing | `sse_parser.dart` | Server-Sent Events protocol |
| Auth support | `auth_interceptor.dart` | Token injection pattern |
| Cancellation | `rpc_cancel_token.dart` | Per-call cancellation |

## CONVENTIONS

- Interceptors extend `RpcInterceptor` and call `next(ctx)` to proceed
- Transport selection via conditional imports (compile-time, not `kIsWeb`)
- `executeWithInterceptors()` in Transport, but generated `Unified<Service>` builds its own chain
- SSE for HTTP server streaming; gRPC delegates to `*ServiceClient` from `*pbgrpc.dart`
- `withRetry` utility wraps Dio requests with configurable retry

## ANTI-PATTERNS

- Don't add runtime deps that can't tree-shake (transport selection MUST be compile-time)
- Don't put interceptor chain logic in Transport — `Unified<Service>` owns the chain
- Don't use `kIsWeb` for transport selection — use conditional imports
