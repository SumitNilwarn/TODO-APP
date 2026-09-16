import '../../../data/api/api_client.dart';
import '../../../data/api/api_paths.dart';
import '../domain/task_list_query.dart';
import '../domain/task_models.dart';

/// Typed access to the backend task-management endpoints (Phase 6/7 contract).
///
/// Mirrors the exact `TaskResponse` / `TaskPageResponse` wire contracts and the
/// documented request shapes. Ownership always comes from the backend
/// principal — the client never sends a `userId`, `completedAt` or `version`.
/// Endpoint paths are composed from [ApiPaths.tasks] so the contract stays
/// centralized.
class TaskApi {
  const TaskApi(this._client);

  final ApiClient _client;

  static Task _parseTask(dynamic data) =>
      Task.fromJson((data as Map).cast<String, dynamic>());

  static TaskPage _parsePage(dynamic data) =>
      TaskPage.fromJson((data as Map).cast<String, dynamic>());

  /// GET /tasks — one bounded page of the caller's tasks.
  ///
  /// [sort] must come from the backend allowlist (`createdAt` | `updatedAt` |
  /// `dueDate` | `title` | `status`, default `createdAt`); [direction] is
  /// `ASC`|`DESC` (default `DESC`).
  Future<TaskPage> listTasks({
    int page = 0,
    int size = kTaskPageSize,
    String sort = 'createdAt',
    String direction = 'DESC',
    TaskStatus? status,
    bool? overdue,
  }) async {
    final response = await _client.get<TaskPage>(
      ApiPaths.tasks,
      queryParameters: {
        'page': '$page',
        'size': '$size',
        'sort': sort,
        'direction': direction,
        if (status != null) 'status': status.apiValue,
        if (overdue != null) 'overdue': '$overdue',
      },
      dataParser: _parsePage,
    );
    return response.data!;
  }

  /// GET /tasks/{taskId} — one task, or 404 `TASK_NOT_FOUND`.
  Future<Task> getTask(String taskId) async {
    final response = await _client.get<Task>(
      '${ApiPaths.tasks}/$taskId',
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// POST /tasks — creates a task. Status defaults to `TODO`; the client never
  /// supplies ownership, `completedAt` or `version`.
  Future<Task> createTask(CreateTaskRequest request) async {
    final response = await _client.post<Task>(
      ApiPaths.tasks,
      body: request.toJson(),
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// PUT /tasks/{taskId} — full replacement (every editable field is sent).
  Future<Task> updateTask(String taskId, UpdateTaskRequest request) async {
    final response = await _client.put<Task>(
      '${ApiPaths.tasks}/$taskId',
      body: request.toJson(),
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// PATCH /tasks/{taskId} — partial update.
  ///
  /// Only keys present in [request] are sent: a string sets the field, an
  /// explicit `null` clears `description`/`dueDate`, and absent keys leave the
  /// field unchanged.
  Future<Task> patchTask(String taskId, TaskPatchRequest request) async {
    final response = await _client.patch<Task>(
      '${ApiPaths.tasks}/$taskId',
      body: request.toJson(),
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// PATCH /tasks/{taskId}/status — sets the status, enforcing lifecycle rules.
  Future<Task> updateTaskStatus(String taskId, TaskStatus status) async {
    final response = await _client.patch<Task>(
      '${ApiPaths.tasks}/$taskId/status',
      body: {'status': status.apiValue},
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// PATCH /tasks/{taskId}/complete — completes the task; `completedAt` is set
  /// server-side from the backend clock.
  Future<Task> completeTask(String taskId) async {
    final response = await _client.patch<Task>(
      '${ApiPaths.tasks}/$taskId/complete',
      body: const {},
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// PATCH /tasks/{taskId}/cancel — cancels the task and clears `completedAt`.
  Future<Task> cancelTask(String taskId) async {
    final response = await _client.patch<Task>(
      '${ApiPaths.tasks}/$taskId/cancel',
      body: const {},
      dataParser: _parseTask,
    );
    return response.data!;
  }

  /// DELETE /tasks/{taskId} — deletes the task.
  Future<void> deleteTask(String taskId) async {
    await _client.delete<void>('${ApiPaths.tasks}/$taskId', dataParser: (_) {});
  }

  /// Convenience wrapper that unpacks a [TaskListQuery] into the typed
  /// parameters expected by [listTasks] plus the Phase 14 additions
  /// (search, dueDateFrom, dueDateTo).
  Future<TaskPage> listTasksFromQuery(TaskListQuery query) async {
    final params = query.toQueryParams();
    final response = await _client.get<TaskPage>(
      ApiPaths.tasks,
      queryParameters: params,
      dataParser: _parsePage,
    );
    return response.data!;
  }
}

/// Body for `POST /api/v1/tasks`.
///
/// `title` is required; a blank `description` maps to `null` (the backend's
/// `@NotBlankOrNull` rejects whitespace-only strings, so the client sends
/// `null` instead). `dueDate` is an optional calendar date.
class CreateTaskRequest {
  const CreateTaskRequest({
    required this.title,
    this.description,
    this.dueDate,
  });

  final String title;
  final String? description;
  final DateTime? dueDate;

  Map<String, dynamic> toJson() => {
    'title': title,
    // Explicit null: a blank description is sent as `null` so the server never
    // has to guess whether an omitted key means "unset" for a full CREATION.
    'description': description,
    if (dueDate != null) 'dueDate': isoDateString(dueDate!),
  };
}

/// Body for `PUT /api/v1/tasks/{taskId}` — full replacement. Status is
/// required by the backend contract; lifecycle rules are enforced server-side.
class UpdateTaskRequest {
  const UpdateTaskRequest({
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
  });

  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'status': status.apiValue,
    'dueDate': dueDate == null ? null : isoDateString(dueDate!),
  };
}

/// Body for `PATCH /api/v1/tasks/{taskId}` — partial update.
///
/// Only fields present in [changes] are sent at all; each value is
/// written verbatim — a `null` clears the optional field, a string sets it. A
/// field the user left untouched is absent and stays unchanged. This matches
/// the backend's patch protocol exactly (omitted vs explicit null vs value).
class TaskPatchRequest {
  const TaskPatchRequest(this.changes);

  /// Wire field name → new value (`null` = clear). Preserves insertion order.
  final Map<String, dynamic> changes;

  Map<String, dynamic> toJson() => {
    for (final entry in changes.entries) entry.key: entry.value,
  };

  bool get isEmpty => changes.isEmpty;
}
