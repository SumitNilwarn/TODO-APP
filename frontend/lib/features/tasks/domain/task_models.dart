/// Domain types for the tasks feature (Phase 13).
///
/// Models mirror the backend wire contract exactly: every shape is parsed from
/// the envelope's `data`, and `overdue` is the derived flag the server computes
/// at response time — it is never sent by the client and never stored.
library;

/// Page size used by the task list. Bounded on purpose: every query is a
/// single backend page, never an unbounded download.
const int kTaskPageSize = 15;

/// Task lifecycle state, exactly the backend `TaskStatus` enum.
///
/// `OVERDUE` is deliberately absent: it is a derived flag (see [Task.overdue]),
/// never a persisted status. The UI never sends it.
enum TaskStatus {
  todo('TODO', 'To do'),
  inProgress('IN_PROGRESS', 'In progress'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const TaskStatus(this.apiValue, this.label);

  /// The exact wire value sent to / returned by the backend.
  final String apiValue;

  /// Compact, user-facing label.
  final String label;

  /// Resolves a wire value back into a [TaskStatus], or `null` for unknown
  /// values so the client can degrade gracefully.
  static TaskStatus? fromApi(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// A task owned by the authenticated caller, as returned by the task
/// endpoints. This is the full CRUD model (unlike the read-only dashboard
/// projection) — it carries the optimistic-lock [version] so the client can
/// detect a stale row and recover.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.overdue,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.completedAt,
    this.version = 1,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: TaskStatus.fromApi(json['status'] as String?) ?? TaskStatus.todo,
      dueDate: _parseDate(json['dueDate']),
      completedAt: _parseInstant(json['completedAt']),
      overdue: json['overdue'] == true,
      createdAt:
          _parseInstant(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseInstant(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      version: _toInt(json['version'], fallback: 1),
    );
  }

  final String id;
  final String title;
  final String? description;
  final TaskStatus status;

  /// Local-date deadline (`YYYY-MM-DD`) with no time component, or `null` when
  /// none is set. Never reinterpreted as an instant — timezone shifts are
  /// impossible because the parsed value keeps only y/m/d.
  final DateTime? dueDate;

  /// When the task was completed (UTC instant), or `null` while not completed.
  final DateTime? completedAt;

  /// Derived server-side: past dueDate and not completed/cancelled.
  final bool overdue;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optimistic-lock version from the response. The backend increments it on
  /// every write; a stale concurrent write surfaces as a 409
  /// `OPTIMISTIC_LOCK_CONFLICT`.
  final int version;

  bool get isTerminal =>
      status == TaskStatus.completed || status == TaskStatus.cancelled;
  bool get canStart => status == TaskStatus.todo;
  bool get canComplete =>
      status == TaskStatus.todo || status == TaskStatus.inProgress;
  bool get canCancel =>
      status == TaskStatus.todo || status == TaskStatus.inProgress;

  /// Compact due-date summary for list rows ("Jan 8, 2026" / "No due date").
  String get dueLabel {
    final date = dueDate;
    if (date == null) return 'No due date';
    return formatTaskDate(date);
  }

  /// Whether [other] represents the same task id (identity used for list
  /// diffing after a mutation round-trip).
  bool sameIdAs(Task other) => other.id == id;

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
    bool? overdue,
    DateTime? updatedAt,
    int? version,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description,
      status: status ?? this.status,
      dueDate: dueDate,
      completedAt: completedAt,
      overdue: overdue ?? this.overdue,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  static int _toInt(Object? value, {required int fallback}) {
    if (value is num) return value.toInt();
    return value is int ? value : fallback;
  }
}

/// Paginated task list (`TaskPageResponse`) from `GET /api/v1/tasks`.
class TaskPage {
  const TaskPage({
    required this.tasks,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory TaskPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    final tasks = content is List
        ? content
              .map(
                (item) => Task.fromJson((item as Map).cast<String, dynamic>()),
              )
              .toList()
        : const <Task>[];
    return TaskPage(
      tasks: tasks,
      page: _toInt(json['page']),
      size: _toInt(json['size']),
      totalElements: _toInt(json['totalElements']),
      totalPages: _toInt(json['totalPages']),
      first: json['first'] == true,
      last: json['last'] == true,
    );
  }

  final List<Task> tasks;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  bool get isEmpty => tasks.isEmpty;

  /// The one-based page number shown to users ("Page 2 of 4").
  int get pageNumber => page + 1;

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return value is int ? value : 0;
  }
}

/// Parses a wire `YYYY-MM-DD` date into a timezone-free calendar day, or
/// `null` for absent/invalid values.
DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _parseInstant(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString().trim());
}

/// Formats a calendar date without a time component ("Jan 8, 2026").
String formatTaskDate(DateTime date) {
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

/// Serializes a calendar date to the wire `YYYY-MM-DD` form.
String isoDateString(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Formats a UTC instant in the viewer's local timezone for display
/// ("Jan 8, 2026 · 09:30").
String formatTaskInstant(DateTime instant) {
  final local = instant.toLocal();
  final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  return '${formatTaskDate(local)} · $time';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
