/// Build-time configuration for the Todo App client.
///
/// Values are injected at build/run time via Dart defines so that environment
/// specifics never live in source code:
///
///   flutter run --dart-define=API_BASE_URL=http://localhost:8080
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com
///   flutter build web --dart-define=APP_ENVIRONMENT=production
///
/// Security note: anything shipped to Flutter Web is publicly inspectable.
/// Secrets (JWT secrets, database passwords, private keys, backend
/// credentials) must NEVER be placed here or anywhere in the client — they
/// stay server-side. This config is for public, non-sensitive values only.
abstract final class AppConfig {
  /// Base URL of the backend REST API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Logical environment name injected at build time.
  ///
  /// Accepted values: `development`, `staging`, `production`. Anything else
  /// falls back to [AppEnvironment.development].
  static const String environment = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'development',
  );

  static const bool debugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: true,
  );

  /// Typed view over [environment].
  static AppEnvironment get appEnvironment =>
      AppEnvironment.fromName(environment);
}

/// The kind of environment the web client is running in.
///
/// Kept minimal for the foundation — later phases may use it to enable
/// developer tooling, logging verbosity or feature flags per environment.
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromName(String name) {
    return switch (name.trim().toLowerCase()) {
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => AppEnvironment.development,
    };
  }
}
