/// Client-side validators for the auth forms.
///
/// These mirror the backend's documented rules so the user gets instant,
/// friendly feedback. The server remains authoritative and re-validates every
/// submission — the client never weakens backend constraints.
library;

/// Usernames are 3–50 alphanumeric characters (`.` `_` `-` allowed).
final RegExp usernamePattern = RegExp(r'^[A-Za-z0-9._-]+$');

String? validateUsername(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Enter a username.';
  }
  if (trimmed.length < 3 || trimmed.length > 50) {
    return 'Username must be 3–50 characters long.';
  }
  if (!usernamePattern.hasMatch(trimmed)) {
    return 'Use letters, numbers, dots, dashes or underscores only.';
  }
  return null;
}

final RegExp _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
);

String? validateEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Enter your email address.';
  }
  if (trimmed.length > 255) {
    return 'Email must be under 255 characters.';
  }
  if (!_emailPattern.hasMatch(trimmed)) {
    return 'Enter a valid email address.';
  }
  return null;
}

/// Passwords are 10–100 characters with at least one letter and one digit.
String? validatePassword(String? value) {
  final text = value ?? '';
  if (text.isEmpty) {
    return 'Enter a password.';
  }
  if (text.length < 10 || text.length > 100) {
    return 'Password must be 10–100 characters long.';
  }
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
  final hasDigit = RegExp(r'[0-9]').hasMatch(text);
  if (!hasLetter || !hasDigit) {
    return 'Password must include at least one letter and one number.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Re-enter your password.';
  }
  if (value != password) {
    return 'Passwords do not match.';
  }
  return null;
}
