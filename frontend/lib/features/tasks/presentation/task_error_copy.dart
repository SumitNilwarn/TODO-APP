import '../../../data/api/api_exception.dart';

/// Renders backend/transport failures into safe, friendly copy for task flows.
///
/// The client never leaks backend internals: raw exception text and API error
/// messages are replaced with deterministic, actionable guidance. Known task
/// error codes get tailored copy; everything else collapses to the matching
/// category with a fallback.
abstract final class TaskErrorCopy {
  static String message(ApiException error, {required String fallback}) {
    switch (error.kind) {
      case ApiExceptionKind.network:
        return 'Could not reach the server. Please check your connection.';
      case ApiExceptionKind.timeout:
        return 'The request timed out. Please try again.';
      case ApiExceptionKind.invalid:
        return 'The server sent an unexpected response. Please try again.';
      case ApiExceptionKind.unexpected:
        return fallback;
      case ApiExceptionKind.server:
        break;
    }

    if (error.statusCode == null) return fallback;
    if (error.statusCode! >= 500) {
      return 'An unexpected server error occurred. Please try again.';
    }

    switch (error.code) {
      case 'TASK_NOT_FOUND':
        return 'This task no longer exists. It may have been deleted.';
      case 'INVALID_TRANSITION':
        return "This change isn't allowed for this task's current status. "
            'Refresh to see the latest version.';
      case 'OPTIMISTIC_LOCK_CONFLICT':
        return 'This task was changed elsewhere. '
            'Refresh to get the latest version.';
      default:
        break;
    }

    if (error.statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if (error.statusCode == 403) {
      return "You don't have permission to do that.";
    }
    return fallback;
  }

  /// Copy for a failed task **load** — the caller is the list/detail screen.
  static String forLoad(ApiException error) => message(
    error,
    fallback: 'We couldn\'t load your tasks. Please try again.',
  );

  /// Copy for a failed task **save** (create/edit/status/delete).
  static String forSave(ApiException error) => message(
    error,
    fallback: 'We couldn\'t save your changes. Please try again.',
  );
}
