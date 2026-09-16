import '../../../data/api/api_client.dart';
import '../../../data/api/api_paths.dart';
import '../domain/dashboard_models.dart';

/// Typed access to the backend dashboard + task-list endpoints.
///
/// Mirrors the exact `DashboardResponse` and `TaskPageResponse` wire contracts.
/// Ownership comes from the backend principal — the client never sends a user
/// id, and every task query is bounded (explicit small pages, never "fetch
/// everything").
class DashboardApi {
  const DashboardApi(this._client);

  final ApiClient _client;

  static DashboardSummary _parseSummary(dynamic data) =>
      DashboardSummary.fromJson((data as Map).cast<String, dynamic>());

  static DashboardTaskPage _parseTasks(dynamic data) =>
      DashboardTaskPage.fromJson((data as Map).cast<String, dynamic>());

  /// GET /dashboard — the caller's aggregate counters.
  Future<DashboardSummary> getSummary() async {
    final response = await _client.get<DashboardSummary>(
      ApiPaths.dashboard,
      dataParser: _parseSummary,
    );
    return response.data!;
  }

  /// GET /tasks — one bounded page of the caller's tasks.
  ///
  /// [sort] must come from the backend allowlist (`createdAt` | `updatedAt` |
  /// `dueDate` | `title` | `status`, default `createdAt`); [direction] is
  /// `ASC`|`DESC` (default `DESC`). Optional [status] / [overdue] /
  /// [dueDateFrom] map to the documented filters.
  Future<DashboardTaskPage> getTasks({
    int page = 0,
    int size = 10,
    String sort = 'createdAt',
    String direction = 'DESC',
    DashboardTaskStatus? status,
    bool? overdue,
    DateTime? dueDateFrom,
  }) async {
    final response = await _client.get<DashboardTaskPage>(
      ApiPaths.tasks,
      queryParameters: {
        'page': '$page',
        'size': '$size',
        'sort': sort,
        'direction': direction,
        if (status != null) 'status': status.apiValue,
        if (overdue != null) 'overdue': '$overdue',
        if (dueDateFrom != null) 'dueDateFrom': _isoDate(dueDateFrom),
      },
      dataParser: _parseTasks,
    );
    return response.data!;
  }

  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
