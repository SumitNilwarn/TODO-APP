/// Non-web (VM/tests) backend for [ThemePreferences].
///
/// Deliberately a quiet no-op: tests and embedding apps get the built-in
/// default theme on every launch. Persistence is a web-only enhancement.
String readPreference() => '';

void writePreference(String mode) {}
