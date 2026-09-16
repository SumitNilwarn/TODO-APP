/// Immutable query state for `GET /api/v1/tasks` (Phase 14).
///
/// Encapsulates every server-backed listing parameter so the UI can build,
/// copy, reset, and compare filter/sort/search states without scattering
/// individual fields across the presentation layer.
library;

import 'task_models.dart';

/// All-supported sort fields for the backend allowlist
/// (`createdAt | updatedAt | dueDate | title | status`).
enum TaskSortField {
  createdAt('createdAt', 'Created date'),
  updatedAt('updatedAt', 'Updated date'),
  dueDate('dueDate', 'Due date'),
  title('title', 'Title'),
  status('status', 'Status');

  const TaskSortField(this.apiValue, this.label);

  /// The exact wire value sent to the backend.
  final String apiValue;

  /// User-facing label for UI display.
  final String label;
}

/// Server-backed listing query parameters for a single task-list fetch.
///
/// Every field maps 1-to-1 to a `GET /api/v1/tasks` query parameter. The
/// object is immutable; use [copyWith], [resetPage] and [clearFilters] to
/// derive new states.
class TaskListQuery {
  const TaskListQuery({
    this.page = 0,
    this.size = kTaskPageSize,
    this.sort = TaskSortField.createdAt,
    this.direction = 'DESC',
    this.status,
    this.dueDateFrom,
    this.dueDateTo,
    this.overdue = false,
    this.search = '',
  });

  /// Zero-based page index.
  final int page;

  /// Bounded page size (backend max is 100; we use [kTaskPageSize]).
  final int size;

  /// Active sort field.
  final TaskSortField sort;

  /// Sort direction: `ASC` or `DESC`.
  final String direction;

  /// Status filter (`null` = all statuses).
  final TaskStatus? status;

  /// Inclusive lower bound on due date, or `null`.
  final DateTime? dueDateFrom;

  /// Inclusive upper bound on due date, or `null`.
  final DateTime? dueDateTo;

  /// Whether to send `overdue=true` (`false` = don't send the parameter).
  final bool overdue;

  /// Search query string (trimmed before sending; blank means no search).
  final String search;

  /// Whether any filter is active (excluding sort/direction/page).
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      status != null ||
      dueDateFrom != null ||
      dueDateTo != null ||
      overdue;

  /// Number of active filter parameters (for badge display).
  int get activeFilterCount {
    var count = 0;
    if (search.isNotEmpty) count++;
    if (status != null) count++;
    if (dueDateFrom != null) count++;
    if (dueDateTo != null) count++;
    if (overdue) count++;
    return count;
  }

  /// Returns a new query with [page] reset to 0.
  TaskListQuery resetPage() => copyWith(page: 0);

  /// Clears all filter/search parameters while preserving sort and direction.
  TaskListQuery clearFilters() => copyWith(
    search: '',
    status: () => null,
    dueDateFrom: () => null,
    dueDateTo: () => null,
    overdue: false,
    page: 0,
  );

  /// Serialises to the query-parameter map expected by `GET /api/v1/tasks`.
  ///
  /// Only non-default values are included — blank search, null status, and
  /// `overdue=false` are omitted (the backend ignores absent parameters, and
  /// sending `overdue=false` would filter out tasks with no due date).
  Map<String, String> toQueryParams() {
    final trimmedSearch = search.trim();
    return {
      'page': '$page',
      'size': '$size',
      'sort': sort.apiValue,
      'direction': direction,
      if (status != null) 'status': status!.apiValue,
      if (dueDateFrom != null) 'dueDateFrom': _isoDate(dueDateFrom!),
      if (dueDateTo != null) 'dueDateTo': _isoDate(dueDateTo!),
      if (overdue) 'overdue': 'true',
      if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
    };
  }

  TaskListQuery copyWith({
    int? page,
    int? size,
    TaskSortField? sort,
    String? direction,
    TaskStatus? Function()? status,
    DateTime? Function()? dueDateFrom,
    DateTime? Function()? dueDateTo,
    bool? overdue,
    String? search,
  }) {
    return TaskListQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
      status: status != null ? status() : this.status,
      dueDateFrom: dueDateFrom != null ? dueDateFrom() : this.dueDateFrom,
      dueDateTo: dueDateTo != null ? dueDateTo() : this.dueDateTo,
      overdue: overdue ?? this.overdue,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskListQuery &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          size == other.size &&
          sort == other.sort &&
          direction == other.direction &&
          status == other.status &&
          _sameDate(dueDateFrom, other.dueDateFrom) &&
          _sameDate(dueDateTo, other.dueDateTo) &&
          overdue == other.overdue &&
          search == other.search;

  @override
  int get hashCode => Object.hash(
    page,
    size,
    sort,
    direction,
    status,
    _dateKey(dueDateFrom),
    _dateKey(dueDateTo),
    overdue,
    search,
  );

  /// Normalises a date to a value that ignores the time-of-day component, so
  /// [hashCode] agrees with [==] (which compares dates by calendar day).
  static int _dateKey(DateTime? date) {
    if (date == null) return 0;
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
