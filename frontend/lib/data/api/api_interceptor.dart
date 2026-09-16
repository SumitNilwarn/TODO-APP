/// Read-only snapshot of an outgoing API request, passed to interceptors.
///
/// [headers] is deliberately mutable so a future authentication interceptor can
/// inject an `Authorization: Bearer …` header before the request is sent.
class ApiRequestData {
  ApiRequestData({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;
}

/// Snapshot of a received HTTP response (before envelope parsing).
class ApiResponseData {
  const ApiResponseData({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.correlationId,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;

  /// The `X-Correlation-Id` echoed by the backend, when present. Lets the
  /// client join a response with the backend's server-side log line.
  final String? correlationId;
}

/// Hook into the request/response lifecycle of [ApiClient].
///
/// Used for cross-cutting concerns only — e.g. logging, correlation IDs or
/// (in later phases) bearer-token injection. The default implementations are
/// no-ops so features can implement only the hooks they need.
abstract class ApiInterceptor {
  /// Invoked before the request is sent. Mutate [request.headers] to add
  /// headers (e.g. an auth token).
  Future<void> onRequest(ApiRequestData request) async {}

  /// Invoked when the server responded, before envelope parsing.
  Future<void> onResponse(
    ApiRequestData request,
    ApiResponseData response,
  ) async {}

  /// Invoked when the request failed (transport error, timeout, unreadable
  /// body) or a non-2xx status was received.
  Future<void> onError(ApiRequestData request, Object error) async {}
}
