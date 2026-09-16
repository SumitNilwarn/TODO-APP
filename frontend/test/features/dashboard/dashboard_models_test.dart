import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  group('DashboardSummary', () {
    test('parses every counter from the wire contract', () {
      final summary = DashboardSummary.fromJson(const {
        'totalTasks': 8,
        'todoTasks': 3,
        'inProgressTasks': 2,
        'completedTasks': 2,
        'cancelledTasks': 1,
        'overdueTasks': 3,
      });

      expect(summary.totalTasks, 8);
      expect(summary.todoTasks, 3);
      expect(summary.inProgressTasks, 2);
      expect(summary.completedTasks, 2);
      expect(summary.cancelledTasks, 1);
      expect(summary.overdueTasks, 3);
      expect(summary.openTasks, 5);
      expect(summary.hasTasks, isTrue);
      expect(summary.hasOverdue, isTrue);
    });

    test('a zero dashboard is empty and has no overdue work', () {
      final summary = DashboardSummary.fromJson(const {
        'totalTasks': 0,
        'todoTasks': 0,
        'inProgressTasks': 0,
        'completedTasks': 0,
        'cancelledTasks': 0,
        'overdueTasks': 0,
      });

      expect(summary.hasTasks, isFalse);
      expect(summary.hasOverdue, isFalse);
      expect(summary.fractionFor(DashboardTaskStatus.completed), 0);
    });

    test('counts and fractions map to the requested status', () {
      final summary = DashboardSummary.fromJson(const {
        'totalTasks': 10,
        'todoTasks': 4,
        'inProgressTasks': 3,
        'completedTasks': 2,
        'cancelledTasks': 1,
        'overdueTasks': 2,
      });

      expect(summary.countFor(DashboardTaskStatus.todo), 4);
      expect(summary.countFor(DashboardTaskStatus.inProgress), 3);
      expect(summary.countFor(DashboardTaskStatus.completed), 2);
      expect(summary.countFor(DashboardTaskStatus.cancelled), 1);
      expect(
        summary.fractionFor(DashboardTaskStatus.todo),
        closeTo(0.4, 0.0001),
      );
      expect(
        summary.fractionFor(DashboardTaskStatus.cancelled),
        closeTo(0.1, 0.0001),
      );
    });
  });

  group('DashboardTaskStatus', () {
    test('resolves the persisted statuses from their wire values', () {
      expect(DashboardTaskStatus.fromApi('TODO'), DashboardTaskStatus.todo);
      expect(
        DashboardTaskStatus.fromApi('IN_PROGRESS'),
        DashboardTaskStatus.inProgress,
      );
      expect(
        DashboardTaskStatus.fromApi('COMPLETED'),
        DashboardTaskStatus.completed,
      );
      expect(
        DashboardTaskStatus.fromApi('CANCELLED'),
        DashboardTaskStatus.cancelled,
      );
    });

    test('unknown and absent values resolve to null (never OVERDUE)', () {
      expect(DashboardTaskStatus.fromApi('OVERDUE'), isNull);
      expect(DashboardTaskStatus.fromApi('BOGUS'), isNull);
      expect(DashboardTaskStatus.fromApi(null), isNull);
    });

    test('keeps wire values and labels stable', () {
      expect(DashboardTaskStatus.todo.apiValue, 'TODO');
      expect(DashboardTaskStatus.todo.label, 'To do');
      expect(DashboardTaskStatus.inProgress.label, 'In progress');
    });
  });

  group('DashboardTask', () {
    test('parses a full task row', () {
      final task = DashboardTask.fromJson(const {
        'id': 'task-1',
        'title': 'Write the weekly report',
        'description': 'Summarise sprint progress.',
        'status': 'IN_PROGRESS',
        'dueDate': '2026-01-15',
        'completedAt': null,
        'overdue': true,
        'createdAt': '2026-01-08T09:30:00Z',
        'updatedAt': '2026-01-08T09:30:00Z',
        'version': 3,
      });

      expect(task.id, 'task-1');
      expect(task.title, 'Write the weekly report');
      expect(task.status, DashboardTaskStatus.inProgress);
      expect(task.dueDate, DateTime(2026, 1, 15));
      expect(task.overdue, isTrue);
      expect(task.createdAt.year, 2026);
      expect(task.dueLabel, 'Jan 15, 2026');
    });

    test('parses optional nulls and a completed task', () {
      final task = DashboardTask.fromJson(const {
        'id': 'task-2',
        'title': 'Ship the release',
        'description': null,
        'status': 'COMPLETED',
        'dueDate': null,
        'completedAt': '2026-01-10T09:20:00Z',
        'overdue': false,
        'createdAt': '2026-01-06T11:00:00Z',
        'updatedAt': '2026-01-10T09:20:00Z',
        'version': 1,
      });

      expect(task.description, isNull);
      expect(task.dueDate, isNull);
      expect(task.completedAt, isNotNull);
      expect(task.overdue, isFalse);
      expect(task.dueLabel, 'No due date');
    });
  });

  group('DashboardTaskPage', () {
    test('parses content and pagination metadata', () {
      final page = DashboardTaskPage.fromJson(const {
        'content': [
          {
            'id': 'a',
            'title': 'One',
            'description': null,
            'status': 'TODO',
            'dueDate': null,
            'completedAt': null,
            'overdue': false,
            'createdAt': '2026-01-01T00:00:00Z',
            'updatedAt': '2026-01-01T00:00:00Z',
            'version': 1,
          },
          {
            'id': 'b',
            'title': 'Two',
            'description': null,
            'status': 'COMPLETED',
            'dueDate': '2026-01-02',
            'completedAt': '2026-01-02T08:00:00Z',
            'overdue': false,
            'createdAt': '2026-01-01T00:00:00Z',
            'updatedAt': '2026-01-02T08:00:00Z',
            'version': 1,
          },
        ],
        'page': 0,
        'size': 2,
        'totalElements': 2,
        'totalPages': 1,
        'first': true,
        'last': true,
      });

      expect(page.tasks, hasLength(2));
      expect(page.tasks.first.title, 'One');
      expect(page.page, 0);
      expect(page.size, 2);
      expect(page.totalElements, 2);
      expect(page.totalPages, 1);
      expect(page.isEmpty, isFalse);
    });

    test('an empty page reports as empty', () {
      final page = DashboardTaskPage.fromJson(const {
        'content': <Object>[],
        'page': 0,
        'size': 0,
        'totalElements': 0,
        'totalPages': 0,
      });

      expect(page.isEmpty, isTrue);
    });
  });
}
