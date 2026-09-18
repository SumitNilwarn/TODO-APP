import 'theme_preferences_io.dart'
    if (dart.library.js_interop) 'theme_preferences_web.dart'
    as impl;

/// Persists the active theme between sessions without adding any dependency.
///
/// On the web this is backed by `localStorage`; everywhere else (VM, tests,
/// embedding) it degrades to a no-op, so the app keeps its default theme and
/// tests stay deterministic.
abstract final class ThemePreferences {
  static const String graphite = 'graphite';
  static const String white = 'white';

  /// The saved mode from a previous session, or `''` when nothing is stored.
  static String get storedMode => impl.readPreference();

  /// Remembers [mode] (one of [graphite] / [white]) for the next launch.
  static void persist(String mode) => impl.writePreference(mode);
}
