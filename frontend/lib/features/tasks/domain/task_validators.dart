/// Client-side validators for the task forms.
///
/// These mirror the backend's documented rules so the user gets instant,
/// friendly feedback. The server remains authoritative and re-validates every
/// submission — the client never weakens backend constraints.
library;

/// Maximum title length enforced by the backend (`Task.TITLE_MAX_LENGTH`).
const int kTaskTitleMaxLength = 200;

/// Maximum description length enforced by the backend
/// (`Task.DESCRIPTION_MAX_LENGTH`).
const int kTaskDescriptionMaxLength = 2000;

/// Maximum search query length enforced by the task list service
/// (`TaskService.MAX_SEARCH_LENGTH`).
const int kTaskSearchMaxLength = 200;

/// A non-blank title of at most 200 characters (backend: `@NotBlank`,
/// `@Size(max = 200)`).
String? validateTaskTitle(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Enter a title.';
  }
  if (trimmed.length > kTaskTitleMaxLength) {
    return 'Title must be at most 200 characters long.';
  }
  return null;
}

/// An optional description of at most 2000 characters. Blank input is allowed
/// (it maps to `null` on the wire); only over-length is rejected.
String? validateTaskDescription(String? value) {
  final text = value ?? '';
  if (text.length > kTaskDescriptionMaxLength) {
    return 'Description must be at most 2000 characters long.';
  }
  return null;
}
