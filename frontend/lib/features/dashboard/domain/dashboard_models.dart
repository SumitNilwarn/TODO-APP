/// Domain types for the dashboard feature.
///
/// Models mirror the backend wire contract exactly (`docs/api-overview.md`):
/// every shape is parsed from the envelope's `data`, and values that can never
/// be `null` are required on the Dart side.
library;

/// Owner-scoped summary counts from `GET /api/v1/dashboard`.
///
/// All counters are aggregated server-side for the authenticated principal —
/// the client never sends a user id.
class DashboardSummary {
  const DashboardSummary({
    required this.totalTasks,
    required this.todoTasks,
    required this.inProgressTasks,
    required this.completedTasks,
    required this.cancelledTasks,
    required this.overdueTasks,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalTasks: _toCount(json['totalTasks']),
      todoTasks: _toCount(json['todoTasks']),
      inProgressTasks: _toCount(json['inProgressTasks']),
      completedTasks: _toCount(json['completedTasks']),
      cancelledTasks: _toCount(json['cancelledTasks']),
      overdueTasks: _toCount(json['overdueTasks']),
    );
  }

  final int totalTasks;
  final int todoTasks;
  final int inProgressTasks;
  final int completedTasks;
  final int cancelledTasks;
  final int overdueTasks;

  /// Number of tasks still being worked on (to do + in progress).
  int get openTasks => todoTasks + inProgressTasks;

  /// Count of a given [status] within the summary.
  int countFor(DashboardTaskStatus status) {
    return switch (status) {
      DashboardTaskStatus.todo => todoTasks,
      DashboardTaskStatus.inProgress => inProgressTasks,
      DashboardTaskStatus.completed => completedTasks,
      DashboardTaskStatus.cancelled => cancelledTasks,
    };
  }

  /// Share (0–1) of all tasks that carry [status].
  double fractionFor(DashboardTaskStatus status) {
    if (totalTasks <= 0) return 0;
    return countFor(status) / totalTasks;
  }

  bool get hasTasks => totalTasks > 0;
  bool get hasOverdue => overdueTasks > 0;

  /// Human-readable label for a single counter.
  String labelFor(DashboardTaskStatus status) => status.label;

  static int _toCount(Object? value) {
    if (value is num) return value.toInt();
    return value is int ? value : 0;
  }
}

/// Task status exactly as the backend `TaskStatus` enum represents it.
///
/// `OVERDUE` is deliberately absent: it is a derived flag (see [DashboardTask
/// .overdue]), never a persisted status.
enum DashboardTaskStatus {
  todo('TODO', 'To do'),
  inProgress('IN_PROGRESS', 'In progress'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const DashboardTaskStatus(this.apiValue, this.label);

  /// The exact wire value sent to / returned by the backend.
  final String apiValue;

  /// Compact, user-facing label for compact status controls.
  final String label;

  /// Resolves a wire value back into a [DashboardTaskStatus], or `null` for
  /// unknown/absent values so the client can degrade gracefully.
  static DashboardTaskStatus? fromApi(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// A single task owned by the authenticated caller, scaled down to what the
/// dashboard needs (no body/audit fields beyond the list contract).
class DashboardTask {
  const DashboardTask({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    this.completedAt,
    required this.overdue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DashboardTask.fromJson(Map<String, dynamic> json) {
    return DashboardTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status:
          DashboardTaskStatus.fromApi(json['status'] as String?) ??
          DashboardTaskStatus.todo,
      dueDate: _parseDate(json['dueDate']),
      completedAt: _parseInstant(json['completedAt']),
      overdue: json['overdue'] == true,
      createdAt:
          _parseInstant(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseInstant(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String title;
  final String? description;
  final DashboardTaskStatus status;

  /// Local-date deadline (`YYYY-MM-DD`), or `null` when none is set.
  final DateTime? dueDate;

  /// When the task was completed, or `null` while not completed.
  final DateTime? completedAt;

  /// Derived server-side: past dueDate and not completed/cancelled.
  final bool overdue;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// A short "$relative" due-date summary for list rows ("Dec 31", "in 2 days").
  String get dueLabel {
    final date = dueDate;
    if (date == null) return 'No due date';
    return _formatDate(date);
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _parseInstant(Object? value) =>
      DateTime.tryParse(value.toString().trim());
}

/// Paginated task list (`TaskPageResponse`) from `GET /api/v1/tasks`.
class DashboardTaskPage {
  const DashboardTaskPage({
    required this.tasks,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory DashboardTaskPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    final tasks = content is List
        ? content
              .map(
                (item) => DashboardTask.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ),
              )
              .toList()
        : const <DashboardTask>[];
    return DashboardTaskPage(
      tasks: tasks,
      page: _toInt(json['page']),
      size: _toInt(json['size']),
      totalElements: _toInt(json['totalElements']),
      totalPages: _toInt(json['totalPages']),
    );
  }

  final List<DashboardTask> tasks;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get isEmpty => tasks.isEmpty;

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return value is int ? value : 0;
  }
}

/// Compact, locale-free date formatting ("Jan 3, 2026") used by dashboard rows.
String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
