import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/api/api_client.dart';
import 'package:todo_app/data/api/api_exception.dart';
import 'package:todo_app/features/dashboard/data/dashboard_api.dart';
import 'package:todo_app/features/dashboard/domain/dashboard_models.dart';

import '../../support/mock_api.dart';

const _base = 'http://test.local';

void main() {
  DashboardApi api(MockApiServer server) =>
      DashboardApi(ApiClient(baseUrl: _base, httpClient: server.client));

  group('DashboardApi.getSummary', () {
    test('parses the owner-scoped counters', () async {
      final server = MockApiServer();
      final summary = await api(server).getSummary();

      expect(summary.totalTasks, 8);
      expect(summary.todoTasks, 3);
      expect(summary.inProgressTasks, 2);
      expect(summary.completedTasks, 2);
      expect(summary.cancelledTasks, 1);
      expect(summary.overdueTasks, 3);
      expect(server.dashboardGetCalls, 1);
      expect(server.requests.last.url.path, '/api/v1/dashboard');
    });

    test('surfaces a server failure', () async {
      final server = MockApiServer(behavior: Behavior(failDashboardGet: true));
      await expectLater(
        api(server).getSummary(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.kind, 'kind', ApiExceptionKind.server),
        ),
      );
    });
  });

  group('DashboardApi.getTasks', () {
    test('sends bounded pagination with the default sort by default', () async {
      final server = MockApiServer();
      final page = await api(server).getTasks();

      expect(page.tasks, isNotEmpty);
      expect(server.tasksGetCalls, 1);
      final query = server.requests.last.url.queryParameters;
      expect(query['page'], '0');
      expect(query['size'], '10');
      expect(query['sort'], 'createdAt');
      expect(query['direction'], 'DESC');
      expect(query.containsKey('status'), isFalse);
      expect(query.containsKey('overdue'), isFalse);
      expect(query.containsKey('dueDateFrom'), isFalse);
    });

    test('maps optional status / overdue / dueDateFrom filters', () async {
      final server = MockApiServer();
      await api(server).getTasks(
        size: 5,
        status: DashboardTaskStatus.todo,
        overdue: true,
        dueDateFrom: DateTime(2026, 1, 1),
      );

      final query = server.requests.last.url.queryParameters;
      expect(query['status'], 'TODO');
      expect(query['overdue'], 'true');
      expect(query['dueDateFrom'], '2026-01-01');
      expect(query['size'], '5');
    });

    test('applies a bounded overdue=true query to returned rows', () async {
      final server = MockApiServer();
      final page = await api(server).getTasks(overdue: true, size: 5);

      expect(page.tasks, isNotEmpty);
      expect(page.tasks.every((task) => task.overdue), isTrue);
    });

    test('applies status and overdue filters to returned rows', () async {
      final server = MockApiServer();
      final page = await api(server)
          .getTasks(status: DashboardTaskStatus.todo, overdue: true);

      expect(
        page.tasks.every((task) => task.status == DashboardTaskStatus.todo),
        isTrue,
      );
      expect(page.tasks.every((task) => task.overdue), isTrue);
    });

    test('surfaces a server failure', () async {
      final server = MockApiServer(behavior: Behavior(failTasksGet: true));
      await expectLater(
        api(server).getTasks(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
