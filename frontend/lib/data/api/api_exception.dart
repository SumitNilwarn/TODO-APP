import 'api_error.dart';

/// Kind of failure captured by [ApiException].
enum ApiExceptionKind {
  /// The server answered with an HTTP error and a parseable `ApiError` body.
  server,

  /// The client could not reach the server (connection refused, DNS, …).
  network,

  /// The request timed out before a response arrived.
  timeout,

  /// The server answered, but the body violated the documented contract.
  invalid,

  /// An unexpected client-side failure while preparing/sending the request.
  unexpected,
}

/// The exception surfaced by [ApiClient] for any non-2xx API result or
/// transport failure.
///
/// For server errors it carries the parsed [ApiError] data (code, message,
/// field-level details, path) so presentation layers can render the envelope
/// without re-parsing and without hard-coding every possible error code.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.statusCode,
    this.code = 'UNKNOWN_ERROR',
    this.message,
    this.details = const [],
    this.path,
    this.timestamp,
    this.correlationId,
    this.cause,
  });

  /// Convenience constructor from a parsed [ApiError] body.
  ///
  /// [path] and [timestamp] are forwarded from the outer envelope when
  /// provided — they take precedence over the (typically absent) values
  /// inside the nested error block. [correlationId] is the backend echo.
  factory ApiException.fromError(
    ApiError error, {
    int? statusCode,
    String? path,
    DateTime? timestamp,
    String? correlationId,
    Object? cause,
  }) {
    return ApiException(
      kind: ApiExceptionKind.server,
      statusCode: statusCode,
      code: error.code,
      message: error.message,
      details: error.details,
      path: path ?? error.path,
      timestamp: timestamp ?? error.timestamp,
      correlationId: correlationId,
      cause: cause,
    );
  }

  /// A transport-level failure (no response at all).
  factory ApiException.network(Object cause) {
    return ApiException(
      kind: ApiExceptionKind.network,
      code: 'NETWORK_ERROR',
      message: 'Could not reach the server. Please check your connection.',
      cause: cause,
    );
  }

  /// A request that timed out while waiting for a response.
  factory ApiException.timeout(Object cause) {
    return ApiException(
      kind: ApiExceptionKind.timeout,
      code: 'TIMEOUT',
      message: 'The request timed out. Please try again.',
      cause: cause,
    );
  }

  /// A response that did not match the `ApiResponse`/`ApiError` contract.
  factory ApiException.invalid({int? statusCode, Object? cause}) {
    return ApiException(
      kind: ApiExceptionKind.invalid,
      statusCode: statusCode,
      code: 'INVALID_RESPONSE',
      message: 'The server returned an unreadable response.',
      cause: cause,
    );
  }

  /// A fallback for 2xx responses that do not carry a parseable envelope.
  final ApiExceptionKind kind;
  final int? statusCode;
  final String code;
  final String? message;
  final List<ApiErrorDetail> details;
  final String? path;
  final DateTime? timestamp;
  final String? correlationId;
  final Object? cause;

  bool get isNetworkError => kind == ApiExceptionKind.network;
  bool get isTimeout => kind == ApiExceptionKind.timeout;

  @override
  String toString() {
    final buf = StringBuffer('ApiException(${kind.name}');
    if (statusCode != null) {
      buf.write(', http $statusCode');
    }
    buf.write(', $code');
    if (message != null) {
      buf.write(': $message');
    }
    buf.write(')');
    return buf.toString();
  }
}
