import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/api/api_client.dart';
import 'package:todo_app/data/api/api_exception.dart';
import 'package:todo_app/features/tasks/data/task_api.dart';
import 'package:todo_app/features/tasks/domain/task_list_query.dart';
import 'package:todo_app/features/tasks/domain/task_models.dart';

import '../../support/mock_api.dart';

const _base = 'http://test.local';

void main() {
  TaskApi api(MockApiServer server) =>
      TaskApi(ApiClient(baseUrl: _base, httpClient: server.client));

  group('TaskApi.listTasks', () {
    test('sends bounded pagination plus sort defaults', () async {
      final server = MockApiServer();
      final page = await api(server).listTasks();

      final request = server.requests.last;
      expect(request.url.path, '/api/v1/tasks');
      expect(request.method, 'GET');
      expect(request.url.queryParameters['page'], '0');
      expect(request.url.queryParameters['size'], '15');
      expect(request.url.queryParameters['sort'], 'createdAt');
      expect(request.url.queryParameters['direction'], 'DESC');
      expect(page.tasks, hasLength(6));
      expect(page.totalElements, 6);
      expect(page.totalPages, 1);
      expect(server.tasksGetCalls, 1);
    });

    test('forwards status and overdue filters', () async {
      final server = MockApiServer();
      await api(server).listTasks(
        status: TaskStatus.completed,
        overdue: true,
        page: 2,
        size: 5,
      );

      final request = server.requests.last;
      expect(request.url.queryParameters['status'], 'COMPLETED');
      expect(request.url.queryParameters['overdue'], 'true');
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['size'], '5');
    });

    test('omits optional filters when unset', () async {
      final server = MockApiServer();
      await api(server).listTasks();
      final request = server.requests.last;
      expect(request.url.queryParameters.containsKey('status'), isFalse);
      expect(request.url.queryParameters.containsKey('overdue'), isFalse);
    });
  });

  group('TaskApi.listTasksFromQuery', () {
    test('sends page, size, sort and direction from a query', () async {
      final server = MockApiServer();
      const query = TaskListQuery(
        page: 2,
        size: 25,
        sort: TaskSortField.title,
        direction: 'ASC',
      );
      final page = await api(server).listTasksFromQuery(query);

      final request = server.requests.last;
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['size'], '25');
      expect(request.url.queryParameters['sort'], 'title');
      expect(request.url.queryParameters['direction'], 'ASC');
      expect(page.totalElements, 6);
      expect(server.tasksGetCalls, 1);
    });

    test('forwards search, status, overdue and due-date bounds', () async {
      final server = MockApiServer();
      final query = TaskListQuery(
        search: 'weekly',
        status: TaskStatus.inProgress,
        overdue: true,
        dueDateFrom: DateTime(2026, 1, 1),
        dueDateTo: DateTime(2026, 1, 31),
      );
      await api(server).listTasksFromQuery(query);

      final params = server.requests.last.url.queryParameters;
      expect(params['search'], 'weekly');
      expect(params['status'], 'IN_PROGRESS');
      expect(params['overdue'], 'true');
      expect(params['dueDateFrom'], '2026-01-01');
      expect(params['dueDateTo'], '2026-01-31');
    });

    test('omits unset filters so defaults come from the backend', () async {
      final server = MockApiServer();
      await api(server).listTasksFromQuery(const TaskListQuery());

      final params = server.requests.last.url.queryParameters;
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('status'), isFalse);
      expect(params.containsKey('overdue'), isFalse);
      expect(params.containsKey('dueDateFrom'), isFalse);
      expect(params.containsKey('dueDateTo'), isFalse);
    });

    test('search filters title or description case-insensitively', () async {
      final server = MockApiServer();
      final page = await api(server)
          .listTasksFromQuery(const TaskListQuery(search: 'SUMMIT'));

      expect(page.tasks.map((t) => t.title), ['Book travel for the summit']);
      expect(page.totalElements, 1);
    });

    test('due-date bounds are inclusive on both ends', () async {
      final server = MockApiServer();
      final page = await api(server).listTasksFromQuery(
        TaskListQuery(
          dueDateFrom: DateTime(2026, 1, 10),
          dueDateTo: DateTime(2026, 1, 25),
        ),
      );

      expect(
        page.tasks.map((t) => t.title),
        containsAll(['Ship the design tokens', 'Prepare sprint retrospective']),
      );
      expect(page.tasks.every((t) => t.dueDate != null), isTrue);
    });

    test('sorts by title ascending when requested', () async {
      final server = MockApiServer();
      final page = await api(server).listTasksFromQuery(
        const TaskListQuery(sort: TaskSortField.title, direction: 'ASC'),
      );

      final titles = page.tasks.map((t) => t.title).toList();
      final sorted = List<String>.from(titles)..sort();
      expect(titles, sorted);
      expect(titles.first, 'Book travel for the summit');
    });
  });

  group('TaskApi single-task endpoints', () {
    test('getTask hits /tasks/{id}', () async {
      final server = MockApiServer();
      final task = await api(server).getTask('task-1');

      expect(server.requests.last.url.path, '/api/v1/tasks/task-1');
      expect(server.requests.last.method, 'GET');
      expect(task.id, 'task-1');
      expect(task.title, 'Write the weekly report');
      expect(task.status, TaskStatus.inProgress);
      expect(server.taskGetCalls, 1);
    });

    test('createTask POSTs title/description/dueDate only', () async {
      final server = MockApiServer();
      final task = await api(server).createTask(
        const CreateTaskRequest(
          title: 'Plan the launch',
          description: 'First milestone',
          dueDate: null,
        ),
      );

      expect(server.requests.last.url.path, '/api/v1/tasks');
      expect(server.requests.last.method, 'POST');
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body, {
        'title': 'Plan the launch',
        'description': 'First milestone',
      });
      expect(task.id, 'task-11');
      expect(task.title, 'Plan the launch');
      expect(task.status, TaskStatus.todo);
      expect(server.taskCreateCalls, 1);
    });

    test(
      'createTask sends description explicitly (null when absent)',
      () async {
        final server = MockApiServer();
        await api(server)
            .createTask(const CreateTaskRequest(title: 'Only title'));
        final body =
            jsonDecode(server.requests.last.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {'title', 'description'});
        expect(body['description'], isNull);
      },
    );

    test('createTask sends date-only dueDate', () async {
      final server = MockApiServer();
      await api(server).createTask(
        const CreateTaskRequest(title: 'Plan the launch', dueDate: null),
      );
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.containsKey('dueDate'), isFalse);
    });

    test('updateTask PUTs the full replacement body', () async {
      final server = MockApiServer();
      final task = await api(server).updateTask(
        'task-1',
        const UpdateTaskRequest(
          title: 'Write the monthly report',
          description: null,
          status: TaskStatus.completed,
          dueDate: null,
        ),
      );

      expect(server.requests.last.url.path, '/api/v1/tasks/task-1');
      expect(server.requests.last.method, 'PUT');
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'title', 'description', 'status', 'dueDate'});
      expect(body['title'], 'Write the monthly report');
      expect(body['description'], isNull);
      expect(body['status'], 'COMPLETED');
      expect(body['dueDate'], isNull);
      expect(task.status, TaskStatus.completed);
      expect(server.taskPutCalls, 1);
    });

    test('patchTask sends only the changed fields', () async {
      final server = MockApiServer();
      final task = await api(server).patchTask(
        'task-1',
        TaskPatchRequest({'title': 'Write the monthly report'}),
      );

      expect(server.taskPatchCalls, 1);
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'title'});
      expect(task.title, 'Write the monthly report');
    });

    test('patchTask sends explicit null to clear optional fields', () async {
      final server = MockApiServer();
      await api(server).patchTask(
        'task-1',
        TaskPatchRequest({'description': null, 'dueDate': null}),
      );

      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'description', 'dueDate'});
      expect(body['description'], isNull);
      expect(body['dueDate'], isNull);
    });

    test('patchTask empty request serializes to an empty object', () {
      expect(const TaskPatchRequest({}).toJson(), isEmpty);
      expect(const TaskPatchRequest({}).isEmpty, isTrue);
    });

    test('updateTaskStatus PATCHes /status with apiValue', () async {
      final server = MockApiServer();
      final task = await api(server)
          .updateTaskStatus('task-1', TaskStatus.completed);

      expect(server.requests.last.url.path, '/api/v1/tasks/task-1/status');
      expect(server.requests.last.method, 'PATCH');
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body, {'status': 'COMPLETED'});
      expect(task.status, TaskStatus.completed);
      expect(server.taskStatusCalls, 1);
    });

    test('completeTask and cancelTask hit their endpoints', () async {
      final server = MockApiServer();
      final completed = await api(server).completeTask('task-4');
      expect(server.requests.last.url.path, '/api/v1/tasks/task-4/complete');
      expect(completed.status, TaskStatus.completed);

      final cancelled = await api(server).cancelTask('task-2');
      expect(server.requests.last.url.path, '/api/v1/tasks/task-2/cancel');
      expect(cancelled.status, TaskStatus.cancelled);
      expect(cancelled.completedAt, isNull);
      expect(server.taskCompleteCalls, 1);
      expect(server.taskCancelCalls, 1);
    });

    test('deleteTask issues a DELETE and returns void', () async {
      final server = MockApiServer();
      await api(server).deleteTask('task-2');

      expect(server.requests.last.url.path, '/api/v1/tasks/task-2');
      expect(server.requests.last.method, 'DELETE');
      expect(server.taskDeleteCalls, 1);
    });
  });

  group('TaskApi error handling', () {
    test('getTask throws TASK_NOT_FOUND on 404', () async {
      final server = MockApiServer(behavior: Behavior(missingTask: true));
      await expectLater(
        api(server).getTask('task-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'TASK_NOT_FOUND')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('patchTask throws OPTIMISTIC_LOCK_CONFLICT on 409', () async {
      final server = MockApiServer(
        behavior: Behavior(optimisticLockOnPatch: true),
      );
      await expectLater(
        api(server)
            .patchTask('task-1', const TaskPatchRequest({'title': 'New'})),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'OPTIMISTIC_LOCK_CONFLICT')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('updateTaskStatus throws INVALID_TRANSITION on an illegal move', () async {
      final server = MockApiServer();
      // task-5 is CANCELLED; moving it to IN_PROGRESS is rejected by the mock.
      await expectLater(
        api(server).updateTaskStatus('task-5', TaskStatus.inProgress),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'INVALID_TRANSITION')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('createTask surfaces server validation details', () async {
      final server = MockApiServer(
        behavior: Behavior(
          failCreateTask: true,
          createTaskStatus: 400,
          createTaskCode: 'VALIDATION_ERROR',
          createTaskDetails: const [
            {'field': 'title', 'message': 'Title is required.'},
          ],
        ),
      );
      await expectLater(
        api(server).createTask(const CreateTaskRequest(title: '')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having((e) => e.details, 'details', hasLength(1))
              .having((e) => e.details.first.field, 'field', 'title'),
        ),
      );
    });
  });
}
