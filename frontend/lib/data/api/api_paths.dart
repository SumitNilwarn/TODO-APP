/// Centralized API path constants mirroring the backend's documented routes
/// (`docs/api-overview.md`).
///
/// Feature endpoints are composed on top of [v1]; this keeps the version
/// prefix and the contract in one place.
abstract final class ApiPaths {
  /// Versioned base path of the REST API.
  static const String v1 = '/api/v1';

  /// Authentication endpoints.
  static const String authLogin = '$v1/auth/login';
  static const String authRegister = '$v1/auth/register';
  static const String authRefresh = '$v1/auth/refresh';
  static const String authLogout = '$v1/auth/logout';
  static const String authMe = '$v1/auth/me';

  /// Profile endpoints.
  static const String profile = '$v1/profile';

  /// Dashboard (owner-scoped summary counts) and task-list endpoints.
  static const String dashboard = '$v1/dashboard';
  static const String tasks = '$v1/tasks';
}
