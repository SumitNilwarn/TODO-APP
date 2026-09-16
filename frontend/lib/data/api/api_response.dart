import 'api_envelope.dart';
import 'api_error.dart';

/// A typed, already-parsed successful API response.
///
/// [ApiClient] decodes the raw `data` payload of a success envelope into the
/// caller-provided model using [dataParser], so feature DTOs can stay simple
/// (`factory X.fromJson`).
class ApiResponse<T> {
  const ApiResponse._({
    required this.success,
    this.data,
    this.message,
    this.error,
  });

  const ApiResponse.success(T? data, {String? message})
    : this._(success: true, data: data, message: message);

  const ApiResponse.failure(ApiError error, {String? message})
    : this._(success: false, error: error, message: message);

  final bool success;

  /// Decoded payload, present when [success] is `true`.
  final T? data;

  final String? message;

  /// Present when [success] is `false`.
  final ApiError? error;

  /// Build a typed response from a parsed [ApiEnvelope].
  factory ApiResponse.fromEnvelope(
    ApiEnvelope envelope, {
    required T Function(dynamic data) dataParser,
  }) {
    if (!envelope.success || envelope.hasError) {
      return ApiResponse.failure(
        envelope.error ??
            const ApiError(
              code: 'UNKNOWN_ERROR',
              message: 'The server returned an unrecognized error.',
            ),
        message: envelope.message,
      );
    }
    final raw = envelope.data;
    return ApiResponse.success(
      raw == null ? null : dataParser(raw),
      message: envelope.message,
    );
  }

  /// Parse an already-decoded JSON [json] map into a typed response.
  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    required T Function(dynamic data) dataParser,
  }) {
    return ApiResponse.fromEnvelope(
      ApiEnvelope.fromJson(json),
      dataParser: dataParser,
    );
  }
}
