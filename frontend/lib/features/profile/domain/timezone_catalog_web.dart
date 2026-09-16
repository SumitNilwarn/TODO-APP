import 'dart:js_interop';

import 'timezone_catalog.dart';

/// Web implementation: prefers the browser's authoritative IANA registry via
/// `Intl.supportedValuesOf('timeZone')`, falling back to the curated catalog
/// when the API is unavailable.
Future<List<String>> loadTimezoneCandidates() async {
  try {
    final result = supportedValuesOf('timeZone'.toJS);
    final ids = result.toDart.map((id) => id.toDart).toList()..sort();
    if (ids.isNotEmpty) {
      return List.unmodifiable(ids);
    }
  } catch (_) {
    // Intl registry unavailable — fall through to the curated catalog.
  }
  return List.unmodifiable(curatedTimezoneCatalog);
}

@JS('Intl.supportedValuesOf')
external JSArray<JSString> supportedValuesOf(JSString key);
