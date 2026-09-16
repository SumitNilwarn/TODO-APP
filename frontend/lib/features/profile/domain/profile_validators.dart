/// Client-side validators for the profile form, mirroring the backend's
/// documented field rules. The server remains authoritative.
library;

String? validateNameField(
  String? value, {
  required String label,
  int max = 50,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.length > max) {
    return '$label must be $max characters or fewer.';
  }
  return null;
}

String? validateDisplayName(String? value) =>
    validateNameField(value, label: 'Display name', max: 100);

/// Time zone ids: the backend accepts IANA names plus a short alias set. The
/// client checks the same *shape* (64 chars, no whitespace) and lets the
/// server decide final validity.
String? validateTimezone(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.length > 64) {
    return 'Time zone must be 64 characters or fewer.';
  }
  if (RegExp(r'\s').hasMatch(trimmed)) {
    return 'Time zone ids cannot contain spaces (e.g. America/New_York).';
  }
  return null;
}

/// Profile image URL: an absolute `http(s)` URL with a non-empty host, up to
/// 255 characters.
String? validateProfileImageUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.length > 255) {
    return 'URL must be 255 characters or fewer.';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return 'Enter a valid http(s) URL (e.g. https://example.com/image.png).';
  }
  return null;
}

/// Normalizes a profile value for storage: trimmed or `null` when empty.
String? normalizeProfileValue(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
