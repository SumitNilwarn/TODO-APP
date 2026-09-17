import 'package:flutter/foundation.dart' show kIsWeb;

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
  ///
  /// Resolved in priority order:
  ///  1. an explicit `--dart-define=API_BASE_URL=...`, used for local
  ///     development where the backend lives on a separate origin;
  ///  2. on Flutter Web, the page's own origin — platforms that reverse-proxy
  ///     `/api/*` to a backend service on the same domain (Vercel Services,
  ///     nginx) need no domain baked in, so a single build works for every
  ///     deployment (production, preview, custom domain) without rebuilding;
  ///  3. fallback for tests / desktop: `http://localhost:8080`.
  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.trim().isNotEmpty) {
      return defined;
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'http://localhost:8080';
  }

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
