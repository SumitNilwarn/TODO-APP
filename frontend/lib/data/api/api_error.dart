DateTime? _parseTimestamp(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

/// A single field-level violation produced by the backend.
///
/// Mirrors `error.details[]` entries of the `ApiError` envelope:
/// `{ "field": "dueDate", "message": "must not be null" }`.
class ApiErrorDetail {
  const ApiErrorDetail({this.field, this.message});

  final String? field;
  final String? message;

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      field: json['field'] as String?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'field': field, 'message': message};

  @override
  bool operator ==(Object other) =>
      other is ApiErrorDetail &&
      other.field == field &&
      other.message == message;

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => 'ApiErrorDetail(field: $field, message: $message)';
}

/// Client-side representation of the backend's standardized `ApiError` body.
///
/// The frontend *parses* errors from the wire rather than hard-coding every
/// future error type, so new backend codes flow through unchanged.
class ApiError {
  const ApiError({
    required this.code,
    this.message,
    this.details = const [],
    this.timestamp,
    this.path,
  });

  /// Stable machine-readable code (e.g. `VALIDATION_ERROR`, `TASK_NOT_FOUND`).
  final String code;

  /// Human-readable summary.
  final String? message;

  /// Structured field-level violations (empty for most errors).
  final List<ApiErrorDetail> details;

  /// ISO-8601 UTC time of the failure, when present.
  final DateTime? timestamp;

  /// The request path that failed.
  final String? path;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final detailsJson = json['details'];
    return ApiError(
      code: (json['code'] as String?) ?? 'UNKNOWN_ERROR',
      message: json['message'] as String?,
      details: detailsJson is List
          ? detailsJson
                .whereType<Map<String, dynamic>>()
                .map(ApiErrorDetail.fromJson)
                .toList()
          : const [],
      timestamp: _parseTimestamp(json['timestamp']),
      path: json['path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'details': details.map((d) => d.toJson()).toList(),
    'timestamp': timestamp?.toUtc().toIso8601String(),
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      other is ApiError &&
      other.code == code &&
      other.message == message &&
      _listEquals(other.details, details) &&
      other.timestamp == timestamp &&
      other.path == path;

  @override
  int get hashCode => Object.hash(code, message, path, timestamp);

  @override
  String toString() => 'ApiError(code: $code, message: $message, path: $path)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
