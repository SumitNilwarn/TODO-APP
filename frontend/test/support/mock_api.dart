import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Shared fixtures + a configurable fake backend for widget/unit tests.
///
/// The fake implements the documented envelopes (see `docs/api-overview.md`),
/// keyed off path + method, and records every request for assertions.

const String mockBase = 'http://test.local';

/// A valid token pair.
const Map<String, dynamic> mockTokens = {
  'accessToken': 'access-token-1',
  'refreshToken': 'refresh-token-1',
  'tokenType': 'Bearer',
  'expiresIn': 3600,
};

const Map<String, dynamic> mockUser = {
  'userId': 'user-1',
  'username': 'ada',
  'email': 'ada@example.com',
};

const Map<String, dynamic> mockProfile = {
  'userId': 'user-1',
  'firstName': 'Ada',
  'lastName': 'Lovelace',
  'displayName': 'Ada Lovelace',
  'timezone': 'Europe/London',
  'profileImageUrl': 'https://example.com/ada.png',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
  'version': 1,
};

/// Fixture aggregate counts returned by `GET /api/v1/dashboard`.
const Map<String, dynamic> mockDashboard = {
  'totalTasks': 8,
  'todoTasks': 3,
  'inProgressTasks': 2,
  'completedTasks': 2,
  'cancelledTasks': 1,
  'overdueTasks': 3,
};

/// Fixture task rows returned by `GET /api/v1/tasks`.
///
/// `overdue` mirrors the derived backend flag (past dueDate, not
/// completed/cancelled).
const List<Map<String, dynamic>> mockTasks = [
  {
    'id': 'task-6',
    'title': 'Book travel for the summit',
    'description': 'Hotel and flights for the February summit.',
    'status': 'TODO',
    'dueDate': '2026-01-08',
    'completedAt': null,
    'overdue': true,
    'createdAt': '2026-01-02T09:00:00Z',
    'updatedAt': '2026-01-02T09:00:00Z',
    'version': 1,
  },
  {
    'id': 'task-5',
    'title': 'Drop the cancelled focus group',
    'description': null,
    'status': 'CANCELLED',
    'dueDate': '2026-01-05',
    'completedAt': null,
    'overdue': false,
    'createdAt': '2026-01-03T08:30:00Z',
    'updatedAt': '2026-01-04T12:00:00Z',
    'version': 2,
  },
  {
    'id': 'task-4',
    'title': 'Sketch the onboarding flow',
    'description': 'Whiteboard the first-run experience.',
    'status': 'TODO',
    'dueDate': null,
    'completedAt': null,
    'overdue': false,
    'createdAt': '2026-01-05T15:00:00Z',
    'updatedAt': '2026-01-05T15:00:00Z',
    'version': 1,
  },
  {
    'id': 'task-3',
    'title': 'Ship the design tokens',
    'description': 'Warm palette + spacing scale to the theme.',
    'status': 'COMPLETED',
    'dueDate': '2026-01-10',
    'completedAt': '2026-01-10T09:20:00Z',
    'overdue': false,
    'createdAt': '2026-01-06T11:00:00Z',
    'updatedAt': '2026-01-10T09:20:00Z',
    'version': 3,
  },
  {
    'id': 'task-2',
    'title': 'Prepare sprint retrospective',
    'description': 'Collect feedback from the whole team.',
    'status': 'TODO',
    'dueDate': '2026-01-25',
    'completedAt': null,
    'overdue': false,
    'createdAt': '2026-01-07T10:00:00Z',
    'updatedAt': '2026-01-07T10:00:00Z',
    'version': 1,
  },
  {
    'id': 'task-1',
    'title': 'Write the weekly report',
    'description': 'Summarise sprint progress for stakeholders.',
    'status': 'IN_PROGRESS',
    'dueDate': '2026-01-15',
    'completedAt': null,
    'overdue': true,
    'createdAt': '2026-01-08T09:30:00Z',
    'updatedAt': '2026-01-08T09:30:00Z',
    'version': 1,
  },
];

http.Response jsonResponse(Object body, int status) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> successEnvelope(Object? data, {String? message}) => {
  'success': true,
  'data': data,
  'message': message,
  'timestamp': '2026-01-01T00:00:00Z',
  'path': '/api/v1',
};

Map<String, dynamic> errorEnvelope({
  required String code,
  String? message,
  String? path,
  List<Map<String, dynamic>> details = const [],
}) {
  return {
    'success': false,
    'message': message,
    'timestamp': '2026-01-01T00:00:00Z',
    'path': path,
    'error': {'code': code, 'message': message, 'details': details},
  };
}

/// A fake backend configured through [Behavior].
class Behavior {
  Behavior({
    this.failLogin = false,
    this.loginCode = 'AUTHENTICATION_FAILED',
    this.loginMessage = 'Invalid username or password',
    this.loginDetails = const [],
    this.tokens,
    this.failRegister = false,
    this.registerCode = 'USERNAME_ALREADY_TAKEN',
    this.registerMessage = 'That username is already taken',
    this.registerDetails = const [],
    this.profileNotFound = false,
    this.failProfileGet = false,
    this.failProfilePut = false,
    this.putCode = 'INVALID_RESPONSE',
    this.failProfilePatch = false,
    this.profilePatchStatus = 409,
    this.profilePatchCode = 'OPTIMISTIC_LOCK_CONFLICT',
    this.profilePatchMessage = 'Profile was modified by another request',
    this.failLogout = false,
    this.profile,
    this.dashboard,
    this.failDashboardGet = false,
    this.dashboardErrorStatus = 500,
    this.dashboardErrorCode = 'SERVER_ERROR',
    this.dashboardErrorMessage = 'dashboard boom',
    this.tasksPage,
    this.failTasksGet = false,
    this.tasksErrorStatus = 500,
    this.tasksErrorCode = 'SERVER_ERROR',
    this.tasksErrorMessage = 'tasks boom',
    this.missingTask = false,
    this.failGetTask = false,
    this.getTaskCode = 'TASK_NOT_FOUND',
    this.getTaskMessage = 'Task not found',
    this.failCreateTask = false,
    this.createTaskStatus = 400,
    this.createTaskCode = 'VALIDATION_ERROR',
    this.createTaskMessage = 'Invalid task',
    this.createTaskDetails = const [],
    this.failPatchTask = false,
    this.patchTaskStatus = 400,
    this.patchTaskCode = 'VALIDATION_ERROR',
    this.patchTaskMessage = 'Invalid task data',
    this.optimisticLockOnPatch = false,
    this.failCompleteTask = false,
    this.completeTaskCode = 'INVALID_TRANSITION',
    this.completeTaskMessage = 'Cannot complete a task in this state',
    this.failCancelTask = false,
    this.cancelTaskCode = 'INVALID_TRANSITION',
    this.cancelTaskMessage = 'Cannot cancel a task in this state',
    this.failDeleteTask = false,
    this.deleteTaskCode = 'SERVER_ERROR',
    this.deleteTaskMessage = 'delete boom',
    this.deleteTaskStatus = 500,
    this.responseDelay,
  });

  bool failLogin;
  String loginCode;
  String loginMessage;
  List<Map<String, dynamic>> loginDetails;

  /// Optional token pair returned by login/refresh.
  Map<String, dynamic>? tokens;

  bool failRegister;
  String registerCode;
  String registerMessage;
  List<Map<String, dynamic>> registerDetails;
  bool profileNotFound;
  bool failProfileGet;
  bool failProfilePut;
  String putCode;

  /// When `true`, `PATCH /profile` answers an error envelope built from
  /// [profilePatchStatus] / [profilePatchCode] / [profilePatchMessage].
  bool failProfilePatch;

  int profilePatchStatus;
  String profilePatchCode;
  String profilePatchMessage;

  bool failLogout;

  /// Optional profile payload returned by the profile endpoints.
  Map<String, dynamic>? profile;

  /// Optional dashboard counts payload (defaults to [mockDashboard]).
  Map<String, dynamic>? dashboard;

  /// When `true`, `GET /dashboard` returns an error envelope built from
  /// [dashboardErrorStatus] / [dashboardErrorCode] / [dashboardErrorMessage].
  bool failDashboardGet;

  int dashboardErrorStatus;
  String dashboardErrorCode;
  String dashboardErrorMessage;

  /// When non-null, `GET /tasks` returns this page payload instead of the
  /// filtered fixture.
  Map<String, dynamic>? tasksPage;

  /// When `true`, `GET /tasks` returns an error envelope built from
  /// [tasksErrorStatus] / [tasksErrorCode] / [tasksErrorMessage].
  bool failTasksGet;

  int tasksErrorStatus;
  String tasksErrorCode;
  String tasksErrorMessage;

  /// When `true`, every task item operation (get/patch/status/complete/
  /// cancel/delete) answers 404 `TASK_NOT_FOUND`, as if the task vanished.
  bool missingTask;

  /// When `true`, `GET /tasks/{id}` answers an error envelope built from
  /// [getTaskCode] / [getTaskMessage].
  bool failGetTask;

  String getTaskCode;
  String getTaskMessage;

  /// When `true`, `POST /tasks` answers an error envelope built from
  /// [createTaskStatus] / [createTaskCode] / [createTaskMessage] /
  /// [createTaskDetails].
  bool failCreateTask;

  int createTaskStatus;
  String createTaskCode;
  String createTaskMessage;
  List<Map<String, dynamic>> createTaskDetails;

  /// When `true`, `PATCH /tasks/{id}` answers an error envelope built from
  /// [patchTaskStatus] / [patchTaskCode] / [patchTaskMessage].
  bool failPatchTask;

  int patchTaskStatus;
  String patchTaskCode;
  String patchTaskMessage;

  /// When `true`, `PATCH /tasks/{id}` answers 409 `OPTIMISTIC_LOCK_CONFLICT`,
  /// simulating a stale concurrent write.
  bool optimisticLockOnPatch;

  /// When `true`, `PATCH /tasks/{id}/complete` answers an error envelope
  /// built from [completeTaskCode] / [completeTaskMessage].
  bool failCompleteTask;

  String completeTaskCode;
  String completeTaskMessage;

  /// When `true`, `PATCH /tasks/{id}/cancel` answers an error envelope built
  /// from [cancelTaskCode] / [cancelTaskMessage].
  bool failCancelTask;

  String cancelTaskCode;
  String cancelTaskMessage;

  /// When `true`, `DELETE /tasks/{id}` answers an error envelope built from
  /// [deleteTaskCode] / [deleteTaskMessage].
  bool failDeleteTask;

  String deleteTaskCode;
  String deleteTaskMessage;
  int deleteTaskStatus;

  /// When non-null, `GET /dashboard` and `GET /tasks` delay their response by
  /// this long — used to hold a request in flight while testing refresh
  /// deduplication.
  Duration? responseDelay;
}

class MockApiServer {
  MockApiServer({Behavior? behavior}) : behavior = behavior ?? Behavior();

  final Behavior behavior;
  final List<http.Request> requests = [];
  int refreshCalls = 0;
  int loginCalls = 0;
  int registerCalls = 0;
  int logoutCalls = 0;
  int profileGetCalls = 0;
  int profilePutCalls = 0;
  int profilePatchCalls = 0;
  int dashboardGetCalls = 0;
  int tasksGetCalls = 0;
  int taskGetCalls = 0;
  int taskCreateCalls = 0;
  int taskPutCalls = 0;
  int taskPatchCalls = 0;
  int taskStatusCalls = 0;
  int taskCompleteCalls = 0;
  int taskCancelCalls = 0;
  int taskDeleteCalls = 0;

  /// Mutable task store, seeded from [mockTasks]. Item operations read/write
  /// this so CRUD tests stay faithful to a real backend (create adds a row,
  /// delete removes it, versions advance).
  final List<Map<String, dynamic>> _tasks = [
    for (final task in mockTasks) Map<String, dynamic>.from(task),
  ];

  int _newTaskSequence = 0;

  late final MockClient client = MockClient(handle);

  Future<void> _maybeDelay() async {
    final delay = behavior.responseDelay;
    if (delay != null) {
      await Future.delayed(delay);
    }
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final method = request.method;
    final bodyText = request.body;
    final body = bodyText.isEmpty
        ? null
        : (jsonDecode(bodyText) as Map<String, dynamic>);

    if (path.endsWith('/auth/refresh') && method == 'POST') {
      refreshCalls++;
      if (body?['refreshToken'] == 'refresh-expired') {
        return jsonResponse(
          errorEnvelope(code: 'REFRESH_TOKEN_INVALID', path: path),
          401,
        );
      }
      return jsonResponse(successEnvelope(behavior.tokens ?? mockTokens), 200);
    }
    if (path.endsWith('/auth/login') && method == 'POST') {
      loginCalls++;
      if (behavior.failLogin) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.loginCode,
            message: behavior.loginMessage,
            details: behavior.loginDetails,
            path: path,
          ),
          401,
        );
      }
      return jsonResponse(successEnvelope(behavior.tokens ?? mockTokens), 200);
    }
    if (path.endsWith('/auth/me') && method == 'GET') {
      return jsonResponse(successEnvelope(mockUser), 200);
    }
    if (path.endsWith('/auth/logout') && method == 'POST') {
      logoutCalls++;
      if (behavior.failLogout) {
        return jsonResponse(
          errorEnvelope(code: 'SERVER_ERROR', path: path),
          500,
        );
      }
      return jsonResponse(successEnvelope(null), 200);
    }
    if (path.endsWith('/auth/register') && method == 'POST') {
      registerCalls++;
      if (behavior.failRegister) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.registerCode,
            message: behavior.registerMessage,
            details: behavior.registerDetails,
            path: path,
          ),
          409,
        );
      }
      return jsonResponse(
        successEnvelope({'userId': 'user-1', 'username': body?['username']}),
        201,
      );
    }
    if (path.endsWith('/profile') && method == 'GET') {
      profileGetCalls++;
      if (behavior.failProfileGet) {
        return jsonResponse(
          errorEnvelope(code: 'SERVER_ERROR', message: 'boom', path: path),
          500,
        );
      }
      if (behavior.profileNotFound) {
        return jsonResponse(
          errorEnvelope(
            code: 'PROFILE_NOT_FOUND',
            message: 'Profile not found',
            path: path,
          ),
          404,
        );
      }
      return jsonResponse(
        successEnvelope(behavior.profile ?? mockProfile),
        200,
      );
    }
    if (path.endsWith('/profile') && method == 'PUT') {
      profilePutCalls++;
      if (behavior.failProfilePut) {
        return jsonResponse(
          errorEnvelope(code: behavior.putCode, path: path),
          400,
        );
      }
      return jsonResponse(successEnvelope(mockProfile), 201);
    }
    if (path.endsWith('/profile') && method == 'PATCH') {
      profilePatchCalls++;
      if (behavior.failProfilePatch) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.profilePatchCode,
            message: behavior.profilePatchMessage,
            path: path,
          ),
          behavior.profilePatchStatus,
        );
      }
      return jsonResponse(successEnvelope(mockProfile), 200);
    }
    if (path.endsWith('/dashboard') && method == 'GET') {
      dashboardGetCalls++;
      await _maybeDelay();
      if (behavior.failDashboardGet) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.dashboardErrorCode,
            message: behavior.dashboardErrorMessage,
            path: path,
          ),
          behavior.dashboardErrorStatus,
        );
      }
      return jsonResponse(
        successEnvelope(behavior.dashboard ?? mockDashboard),
        200,
      );
    }
    if (path.startsWith('/api/v1/tasks/') && method == 'GET') {
      taskGetCalls++;
      await _maybeDelay();
      final task = _findTask(path);
      if (task == null || behavior.missingTask || behavior.failGetTask) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.getTaskCode,
            message: behavior.getTaskMessage,
            path: path,
          ),
          404,
        );
      }
      return jsonResponse(successEnvelope(task), 200);
    }
    if (path.endsWith('/tasks') && method == 'POST') {
      taskCreateCalls++;
      await _maybeDelay();
      if (behavior.failCreateTask) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.createTaskCode,
            message: behavior.createTaskMessage,
            details: behavior.createTaskDetails,
            path: path,
          ),
          behavior.createTaskStatus,
        );
      }
      final title = body?['title']?.toString().trim() ?? '';
      if (title.isEmpty) {
        return jsonResponse(
          errorEnvelope(
            code: 'VALIDATION_ERROR',
            message: 'Title must not be blank',
            details: const [
              {'field': 'title', 'message': 'Title is required.'},
            ],
            path: path,
          ),
          400,
        );
      }
      final now = DateTime.now().toUtc();
      final created = <String, dynamic>{
        'id': 'task-${10 + ++_newTaskSequence}',
        'title': title,
        'description': body?['description'],
        'status': body?['status'] ?? 'TODO',
        'dueDate': body?['dueDate'],
        'completedAt': null,
        'overdue': _isOverdue(body?['dueDate'], body?['status'] ?? 'TODO'),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 1,
      };
      _tasks.insert(0, created);
      return jsonResponse(successEnvelope(created), 201);
    }
    if (path.startsWith('/api/v1/tasks/') && method == 'PUT') {
      taskPutCalls++;
      await _maybeDelay();
      final task = _findTask(path);
      if (task == null || behavior.missingTask) {
        return _taskNotFound(path);
      }
      final status = body?['status'];
      task['title'] = body?['title']?.toString().trim() ?? task['title'];
      task['description'] = body?['description'];
      task['status'] = status ?? task['status'];
      task['dueDate'] = body?['dueDate'];
      task['overdue'] = _isOverdue(task['dueDate'], task['status']);
      task['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      task['version'] = (task['version'] as int) + 1;
      return jsonResponse(successEnvelope(task), 200);
    }
    if (path.startsWith('/api/v1/tasks/') && method == 'PATCH') {
      final tail = _itemTail(path);
      if (tail != null && tail.length == 1) {
        taskPatchCalls++;
        await _maybeDelay();
        final task = _findTask(path);
        if (task == null || behavior.missingTask) {
          return _taskNotFound(path);
        }
        if (behavior.optimisticLockOnPatch) {
          return jsonResponse(
            errorEnvelope(
              code: 'OPTIMISTIC_LOCK_CONFLICT',
              message: 'Task was modified by another request',
              path: path,
            ),
            409,
          );
        }
        if (behavior.failPatchTask) {
          return jsonResponse(
            errorEnvelope(
              code: behavior.patchTaskCode,
              message: behavior.patchTaskMessage,
              path: path,
            ),
            behavior.patchTaskStatus,
          );
        }
        if (body != null) {
          for (final key in ['title', 'description', 'dueDate']) {
            if (body.containsKey(key)) task[key] = body[key];
          }
          if (body.containsKey('status')) task['status'] = body['status'];
        }
        task['overdue'] = _isOverdue(task['dueDate'], task['status']);
        task['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        task['version'] = (task['version'] as int) + 1;
        return jsonResponse(successEnvelope(task), 200);
      }
      if (tail != null && tail.length == 2 && tail[1] == 'status') {
        taskStatusCalls++;
        await _maybeDelay();
        final task = _findTask(path);
        if (task == null || behavior.missingTask) {
          return _taskNotFound(path);
        }
        final target = body?['status'];
        final currentStatus = task['status'] as String;
        if (target == null || !_allowedTransition(currentStatus, target)) {
          return jsonResponse(
            errorEnvelope(
              code: 'INVALID_TRANSITION',
              message: 'Cannot move from $currentStatus to $target',
              path: path,
            ),
            409,
          );
        }
        _applyStatusChange(task, target);
        return jsonResponse(successEnvelope(task), 200);
      }
      if (tail != null && tail.length == 2 && tail[1] == 'complete') {
        taskCompleteCalls++;
        await _maybeDelay();
        final task = _findTask(path);
        if (task == null || behavior.missingTask) {
          return _taskNotFound(path);
        }
        if (behavior.failCompleteTask) {
          return jsonResponse(
            errorEnvelope(
              code: behavior.completeTaskCode,
              message: behavior.completeTaskMessage,
              path: path,
            ),
            409,
          );
        }
        if (task['status'] == 'CANCELLED') {
          return jsonResponse(
            errorEnvelope(
              code: 'INVALID_TRANSITION',
              message: 'Cannot complete a cancelled task',
              path: path,
            ),
            409,
          );
        }
        _applyStatusChange(task, 'COMPLETED');
        return jsonResponse(successEnvelope(task), 200);
      }
      if (tail != null && tail.length == 2 && tail[1] == 'cancel') {
        taskCancelCalls++;
        await _maybeDelay();
        final task = _findTask(path);
        if (task == null || behavior.missingTask) {
          return _taskNotFound(path);
        }
        if (behavior.failCancelTask) {
          return jsonResponse(
            errorEnvelope(
              code: behavior.cancelTaskCode,
              message: behavior.cancelTaskMessage,
              path: path,
            ),
            409,
          );
        }
        if (task['status'] == 'COMPLETED') {
          return jsonResponse(
            errorEnvelope(
              code: 'INVALID_TRANSITION',
              message: 'Cannot cancel a completed task',
              path: path,
            ),
            409,
          );
        }
        _applyStatusChange(task, 'CANCELLED');
        return jsonResponse(successEnvelope(task), 200);
      }
      return _taskNotFound(path);
    }
    if (path.startsWith('/api/v1/tasks/') && method == 'DELETE') {
      taskDeleteCalls++;
      await _maybeDelay();
      if (behavior.failDeleteTask) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.deleteTaskCode,
            message: behavior.deleteTaskMessage,
            path: path,
          ),
          behavior.deleteTaskStatus,
        );
      }
      final task = _findTask(path);
      if (task == null || behavior.missingTask) {
        return _taskNotFound(path);
      }
      _tasks.removeAt(_tasks.indexOf(task));
      return jsonResponse(successEnvelope(null), 200);
    }
    if (path.endsWith('/tasks') && method == 'GET') {
      tasksGetCalls++;
      await _maybeDelay();
      if (behavior.failTasksGet) {
        return jsonResponse(
          errorEnvelope(
            code: behavior.tasksErrorCode,
            message: behavior.tasksErrorMessage,
            path: path,
          ),
          behavior.tasksErrorStatus,
        );
      }
      if (behavior.tasksPage != null) {
        return jsonResponse(successEnvelope(behavior.tasksPage), 200);
      }
      final q = request.url.queryParameters;
      List<Map<String, dynamic>> tasks = List<Map<String, dynamic>>.from(
        _tasks,
      );
      final status = q['status'];
      if (status != null && status.isNotEmpty) {
        tasks = tasks.where((t) => t['status'] == status).toList();
      }
      final overdue = q['overdue'];
      if (overdue != null && overdue.isNotEmpty) {
        final flag = overdue == 'true';
        tasks = tasks.where((t) => t['overdue'] == flag).toList();
      }
      final search = q['search'];
      if (search != null && search.trim().isNotEmpty) {
        final lc = search.trim().toLowerCase();
        tasks = tasks.where((t) {
          final title = (t['title'] as String?)?.toLowerCase() ?? '';
          final desc = (t['description'] as String?)?.toLowerCase() ?? '';
          return title.contains(lc) || desc.contains(lc);
        }).toList();
      }
      final dueDateFrom = q['dueDateFrom'];
      if (dueDateFrom != null && dueDateFrom.isNotEmpty) {
        final from = DateTime.tryParse(dueDateFrom);
        if (from != null) {
          tasks = tasks.where((t) {
            final raw = t['dueDate'];
            if (raw == null || raw.toString().isEmpty) return false;
            final d = DateTime.tryParse(raw.toString());
            return d != null && !d.isBefore(from);
          }).toList();
        }
      }
      final dueDateTo = q['dueDateTo'];
      if (dueDateTo != null && dueDateTo.isNotEmpty) {
        final to = DateTime.tryParse(dueDateTo);
        if (to != null) {
          tasks = tasks.where((t) {
            final raw = t['dueDate'];
            if (raw == null || raw.toString().isEmpty) return false;
            final d = DateTime.tryParse(raw.toString());
            return d != null && !d.isAfter(to);
          }).toList();
        }
      }
      final sort = q['sort'];
      final direction = q['direction']?.toUpperCase() ?? 'DESC';
      if (sort != null && sort.isNotEmpty) {
        tasks.sort((a, b) {
          final cmp = switch (sort) {
            'title' => _compareString(
              a['title'] as String?,
              b['title'] as String?,
            ),
            'status' => _compareString(
              a['status'] as String?,
              b['status'] as String?,
            ),
            'createdAt' => _compareIso(
              a['createdAt'] as String?,
              b['createdAt'] as String?,
            ),
            'updatedAt' => _compareIso(
              a['updatedAt'] as String?,
              b['updatedAt'] as String?,
            ),
            'dueDate' => _compareDate(
              a['dueDate'] as String?,
              b['dueDate'] as String?,
            ),
            _ => 0,
          };
          return direction == 'ASC' ? cmp : -cmp;
        });
      }
      final page = int.tryParse(q['page'] ?? '0') ?? 0;
      final pageSize = int.tryParse(q['size'] ?? '10') ?? 10;
      final total = tasks.length;
      final start = (page * pageSize).clamp(0, total);
      final end = (start + pageSize).clamp(0, total);
      final slice = tasks.sublist(start, end);
      return jsonResponse(
        successEnvelope({
          'content': slice,
          'page': page,
          'size': slice.length,
          'totalElements': total,
          'totalPages': total == 0 ? 0 : (total / pageSize).ceil(),
          'first': page == 0,
          'last': end >= total,
        }),
        200,
      );
    }
    return jsonResponse(errorEnvelope(code: 'NOT_FOUND', path: path), 404);
  }

  /// Returns the `['task-1', 'status']` tail of a `/api/v1/tasks/...` path,
  /// or `null` for the collection path `/api/v1/tasks`.
  static List<String>? _itemTail(String path) {
    const prefix = '/api/v1/tasks/';
    if (!path.startsWith(prefix)) return null;
    final tail = path.substring(prefix.length);
    if (tail.isEmpty) return null;
    return tail.split('/');
  }

  Map<String, dynamic>? _findTask(String path) {
    final tail = _itemTail(path);
    if (tail == null || tail.isEmpty) return null;
    final id = tail.first;
    for (final t in _tasks) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  http.Response _taskNotFound(String path) {
    return jsonResponse(
      errorEnvelope(
        code: 'TASK_NOT_FOUND',
        message: 'Task not found',
        path: path,
      ),
      404,
    );
  }

  static bool _allowedTransition(String current, String target) {
    if (current == target) return true;
    return switch ((current, target)) {
      ('TODO', 'IN_PROGRESS') ||
      ('TODO', 'COMPLETED') ||
      ('TODO', 'CANCELLED') ||
      ('IN_PROGRESS', 'COMPLETED') ||
      ('IN_PROGRESS', 'CANCELLED') => true,
      _ => false,
    };
  }

  static void _applyStatusChange(Map<String, dynamic> task, String target) {
    task['status'] = target;
    if (target == 'COMPLETED') {
      task['completedAt'] = DateTime.now().toUtc().toIso8601String();
    } else {
      task['completedAt'] = null;
    }
    task['overdue'] = _isOverdue(task['dueDate'], target);
    task['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    task['version'] = (task['version'] as int) + 1;
  }

  static bool _isOverdue(dynamic dueDateRaw, String status) {
    if (status == 'COMPLETED' || status == 'CANCELLED') return false;
    if (dueDateRaw == null) return false;
    final dueDate = DateTime.tryParse(dueDateRaw.toString());
    if (dueDate == null) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayNorm = DateTime(today.year, today.month, today.day);
    return due.isBefore(todayNorm);
  }

  static int _compareString(String? a, String? b) {
    return (a ?? '').compareTo(b ?? '');
  }

  static int _compareIso(String? a, String? b) {
    final da = a != null ? DateTime.tryParse(a) : null;
    final db = b != null ? DateTime.tryParse(b) : null;
    if (da == null && db == null) return 0;
    if (da == null) return -1;
    if (db == null) return 1;
    return da.compareTo(db);
  }

  static int _compareDate(String? a, String? b) {
    final da = a != null ? DateTime.tryParse(a) : null;
    final db = b != null ? DateTime.tryParse(b) : null;
    if (da == null && db == null) return 0;
    if (da == null) return -1;
    if (db == null) return 1;
    return da.compareTo(db);
  }
}
