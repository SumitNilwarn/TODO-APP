import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/api/api_error.dart';
import 'package:todo_app/data/api/api_exception.dart';
import 'package:todo_app/features/tasks/presentation/task_error_copy.dart';

ApiException _server({
  required int statusCode,
  String code = 'SERVER_ERROR',
  String? message,
}) {
  return ApiException.fromError(
    ApiError(code: code, message: message),
    statusCode: statusCode,
  );
}

void main() {
  group('transport failures', () {
    test('network failures say to check the connection', () {
      expect(
        TaskErrorCopy.message(
          ApiException.network(Exception('boom')),
          fallback: 'fallback',
        ),
        'Could not reach the server. Please check your connection.',
      );
    });

    test('timeouts ask the user to try again', () {
      expect(
        TaskErrorCopy.message(
          ApiException.timeout(Exception('slow')),
          fallback: 'fallback',
        ),
        'The request timed out. Please try again.',
      );
    });

    test('malformed responses never leak internal detail', () {
      expect(
        TaskErrorCopy.message(
          ApiException.invalid(statusCode: 200),
          fallback: 'fallback',
        ),
        'The server sent an unexpected response. Please try again.',
      );
    });

    test('client-side surprises collapse to the caller fallback', () {
      expect(
        TaskErrorCopy.message(
          const ApiException(kind: ApiExceptionKind.unexpected),
          fallback: 'We couldn\'t load your tasks. Please try again.',
        ),
        'We couldn\'t load your tasks. Please try again.',
      );
    });
  });

  group('server error codes', () {
    test('a 5xx is described as an unexpected server error', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 500, code: 'SERVER_ERROR'),
          fallback: 'fallback',
        ),
        'An unexpected server error occurred. Please try again.',
      );
    });

    test('a vanished task points the user at a refresh', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 404, code: 'TASK_NOT_FOUND'),
          fallback: 'fallback',
        ),
        'This task no longer exists. It may have been deleted.',
      );
    });

    test('an illegal status change explains the conflict', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 409, code: 'INVALID_TRANSITION'),
          fallback: 'fallback',
        ),
        "This change isn't allowed for this task's current status. "
        'Refresh to see the latest version.',
      );
    });

    test('a concurrent edit points the user at the latest version', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 409, code: 'OPTIMISTIC_LOCK_CONFLICT'),
          fallback: 'fallback',
        ),
        'This task was changed elsewhere. '
        'Refresh to get the latest version.',
      );
    });
  });

  group('auth boundaries', () {
    test('a 401 asks the user to sign in again', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 401, code: 'TOKEN_INVALID'),
          fallback: 'fallback',
        ),
        'Your session expired. Please sign in again.',
      );
    });

    test('a 403 describes the missing permission without leaking the body', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 403, code: 'ACCESS_DENIED', message: 'secret'),
          fallback: 'fallback',
        ),
        "You don't have permission to do that.",
      );
    });

    test('unknown codes stay at the status-based copy', () {
      expect(
        TaskErrorCopy.message(
          _server(statusCode: 422, code: 'SOMETHING_NEW'),
          fallback: 'fallback',
        ),
        'fallback',
      );
    });
  });

  group('context fallbacks', () {
    test('forLoad falls back to the load copy', () {
      expect(
        TaskErrorCopy.forLoad(
          _server(statusCode: 400, code: 'VALIDATION_ERROR'),
        ),
        'We couldn\'t load your tasks. Please try again.',
      );
    });

    test('forSave falls back to the save copy', () {
      expect(
        TaskErrorCopy.forSave(
          _server(statusCode: 400, code: 'VALIDATION_ERROR'),
        ),
        'We couldn\'t save your changes. Please try again.',
      );
    });
  });
}
