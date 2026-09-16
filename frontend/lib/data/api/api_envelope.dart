import 'api_error.dart';

/// Raw parsed form of the backend envelope, before the client decides whether
/// the response was a success (`data`) or a failure (`error`).
///
/// This mirrors the two documented envelopes (`ApiResponse` success and
/// `ApiError` error) which share `success`, `message`, `timestamp` and `path`.
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.timestamp,
    this.path,
  });

  final bool success;

  /// Raw `data` payload of a success envelope.
  final dynamic data;

  final String? message;

  /// Parsed `error` block of a failure envelope.
  final ApiError? error;

  final DateTime? timestamp;

  final String? path;

  bool get hasError => error != null;

  factory ApiEnvelope.fromJson(Map<String, dynamic> json) {
    final errorJson = json['error'];
    return ApiEnvelope(
      success: json['success'] == true,
      data: json['data'],
      message: json['message'] as String?,
      error: errorJson is Map<String, dynamic>
          ? ApiError.fromJson(errorJson)
          : null,
      timestamp: json['timestamp'] is DateTime
          ? json['timestamp'] as DateTime
          : DateTime.tryParse((json['timestamp'] ?? '').toString()),
      path: json['path'] as String?,
    );
  }
}
