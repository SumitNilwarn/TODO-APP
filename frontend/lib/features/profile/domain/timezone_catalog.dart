import 'timezone_catalog_io.dart'
    if (dart.library.js_interop) 'timezone_catalog_web.dart'
    as impl;

/// Curated list of common IANA time zone ids always available as a fallback
/// (offline, tests, and any platform without `Intl.supportedValuesOf`).
const List<String> curatedTimezoneCatalog = [
  'UTC',
  'GMT',
  'Etc/UTC',
  'Atlantic/Azores',
  'America/Halifax',
  'America/New_York',
  'America/Toronto',
  'America/Vancouver',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Anchorage',
  'Pacific/Honolulu',
  'America/Puerto_Rico',
  'America/Panama',
  'America/Mexico_City',
  'America/Costa_Rica',
  'America/Lima',
  'America/Bogota',
  'America/Caracas',
  'America/Santo_Domingo',
  'America/Sao_Paulo',
  'America/Argentina/Buenos_Aires',
  'America/Santiago',
  'Europe/London',
  'Europe/Dublin',
  'Europe/Lisbon',
  'Europe/Madrid',
  'Europe/Paris',
  'Europe/Brussels',
  'Europe/Amsterdam',
  'Europe/Berlin',
  'Europe/Stockholm',
  'Europe/Oslo',
  'Europe/Copenhagen',
  'Europe/Warsaw',
  'Europe/Prague',
  'Europe/Vienna',
  'Europe/Rome',
  'Europe/Athens',
  'Europe/Helsinki',
  'Europe/Bucharest',
  'Europe/Istanbul',
  'Europe/Moscow',
  'Africa/Cairo',
  'Africa/Casablanca',
  'Africa/Lagos',
  'Africa/Nairobi',
  'Africa/Johannesburg',
  'Asia/Jerusalem',
  'Asia/Dubai',
  'Asia/Riyadh',
  'Asia/Qatar',
  'Asia/Kuwait',
  'Asia/Bahrain',
  'Asia/Tehran',
  'Asia/Kabul',
  'Asia/Karachi',
  'Asia/Colombo',
  'Asia/Kolkata',
  'Asia/Kathmandu',
  'Asia/Dhaka',
  'Asia/Bangkok',
  'Asia/Ho_Chi_Minh',
  'Asia/Jakarta',
  'Asia/Singapore',
  'Asia/Kuala_Lumpur',
  'Asia/Manila',
  'Asia/Shanghai',
  'Asia/Hong_Kong',
  'Asia/Taipei',
  'Asia/Seoul',
  'Asia/Tokyo',
  'Asia/Ulaanbaatar',
  'Australia/Perth',
  'Australia/Adelaide',
  'Australia/Brisbane',
  'Australia/Sydney',
  'Australia/Melbourne',
  'Australia/Hobart',
  'Pacific/Guam',
  'Pacific/Auckland',
  'Pacific/Fiji',
];

/// Loads candidate IANA time zone ids for the searchable/selectable input.
///
/// Preferred source is the browser's own time zone registry
/// (`Intl.supportedValuesOf('timeZone')`) when running on the web — the
/// authoritative list shipped by the runtime rather than a hardcoded database.
/// Any failure (including non-web platforms) falls back to
/// [curatedTimezoneCatalog].
Future<List<String>> loadTimezoneCandidates() => impl.loadTimezoneCandidates();

/// Basic client-side shape check for a time zone value. The backend stays
/// authoritative for validity; this only feeds friendly field-level hints.
bool looksLikeIanaTimezone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.length > 64) return false;
  // IANA ids use letters, digits, `_`, `/`, `.` and `-`; never whitespace.
  final allowed = RegExp(r'^[A-Za-z0-9_./+-]+$');
  return allowed.hasMatch(trimmed);
}

/// Formats a raw time zone value for the input (trims + normalizes spaces).
String normalizeTimezoneInput(String value) => value.trim();
