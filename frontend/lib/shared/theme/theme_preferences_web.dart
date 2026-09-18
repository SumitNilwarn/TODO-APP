import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web backend for [ThemePreferences] — reads/writes a small localStorage key
/// so the chosen theme survives reloads. Uses only the platform JS surface
/// (`dart:js_interop`), so no extra packages are required.
const _key = 'todo_app.theme';

String readPreference() {
  try {
    final storage = globalContext['localStorage'] as JSObject?;
    if (storage == null) return '';
    final value = storage.callMethodVarArgs<JSAny?>('getItem'.toJS, <JSAny?>[
      _key.toJS,
    ]);
    if (value == null) return '';
    return (value as JSString).toDart;
  } catch (_) {
    return '';
  }
}

void writePreference(String mode) {
  try {
    final storage = globalContext['localStorage'] as JSObject?;
    if (storage == null) return;
    storage.callMethodVarArgs<JSAny?>('setItem'.toJS, <JSAny?>[
      _key.toJS,
      mode.toJS,
    ]);
  } catch (_) {
    // Storage can be unavailable (private mode, embedded webviews) — ignore.
  }
}
