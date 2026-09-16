import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/tasks/domain/task_models.dart';

void main() {
  group('TaskStatus', () {
    test('wire values round-trip', () {
      expect(TaskStatus.todo.apiValue, 'TODO');
      expect(TaskStatus.inProgress.apiValue, 'IN_PROGRESS');
      expect(TaskStatus.completed.apiValue, 'COMPLETED');
      expect(TaskStatus.cancelled.apiValue, 'CANCELLED');
      for (final status in TaskStatus.values) {
        expect(TaskStatus.fromApi(status.apiValue), status);
      }
    });

    test('unknown wire values degrade to null', () {
      expect(TaskStatus.fromApi('OVERDUE'), isNull);
      expect(TaskStatus.fromApi('GARBAGE'), isNull);
      expect(TaskStatus.fromApi(null), isNull);
    });

    test('labels are human readable', () {
      expect(TaskStatus.todo.label, 'To do');
      expect(TaskStatus.inProgress.label, 'In progress');
      expect(TaskStatus.completed.label, 'Completed');
      expect(TaskStatus.cancelled.label, 'Cancelled');
    });
  });

  group('Task.fromJson', () {
    const json = {
      'id': 'task-3',
      'title': 'Ship the design tokens',
      'description': 'Warm palette + spacing scale.',
      'status': 'COMPLETED',
      'dueDate': '2026-01-10',
      'completedAt': '2026-01-10T09:20:00Z',
      'overdue': false,
      'createdAt': '2026-01-06T11:00:00Z',
      'updatedAt': '2026-01-10T09:20:00Z',
      'version': 3,
    };

    test('parses every field', () {
      final task = Task.fromJson(json);
      expect(task.id, 'task-3');
      expect(task.title, 'Ship the design tokens');
      expect(task.description, 'Warm palette + spacing scale.');
      expect(task.status, TaskStatus.completed);
      expect(task.dueDate, DateTime(2026, 1, 10));
      expect(task.completedAt, DateTime.utc(2026, 1, 10, 9, 20));
      expect(task.overdue, isFalse);
      expect(task.createdAt, DateTime.utc(2026, 1, 6, 11));
      expect(task.updatedAt, DateTime.utc(2026, 1, 10, 9, 20));
      expect(task.version, 3);
    });

    test('dueDate stays a calendar date with no time component', () {
      final task = Task.fromJson(json);
      expect(task.dueDate!.hour, 0);
      expect(task.dueDate!.minute, 0);
    });

    test('handles absent optional fields', () {
      final task = Task.fromJson({
        'id': 'task-4',
        'title': 'Sketch the onboarding flow',
        'status': 'TODO',
        'overdue': false,
        'createdAt': '2026-01-05T15:00:00Z',
        'updatedAt': '2026-01-05T15:00:00Z',
      });
      expect(task.description, isNull);
      expect(task.dueDate, isNull);
      expect(task.completedAt, isNull);
      expect(task.status, TaskStatus.todo);
      expect(task.version, 1);
    });

    test('unknown status falls back to todo', () {
      final task = Task.fromJson({
        'id': 'x',
        'title': 'Odd',
        'status': 'OVERDUE',
        'overdue': true,
        'createdAt': '2026-01-05T15:00:00Z',
        'updatedAt': '2026-01-05T15:00:00Z',
      });
      expect(task.status, TaskStatus.todo);
    });
  });

  group('Task lifecycle helpers', () {
    Task taskWith(TaskStatus status) {
      return Task(
        id: 't1',
        title: 'T',
        status: status,
        overdue: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('open tasks can advance through the lifecycle', () {
      expect(taskWith(TaskStatus.todo).canStart, isTrue);
      expect(taskWith(TaskStatus.todo).canComplete, isTrue);
      expect(taskWith(TaskStatus.todo).canCancel, isTrue);
      expect(taskWith(TaskStatus.inProgress).canStart, isFalse);
      expect(taskWith(TaskStatus.inProgress).canComplete, isTrue);
      expect(taskWith(TaskStatus.inProgress).canCancel, isTrue);
    });

    test('terminal tasks hide lifecycle actions but stay managed', () {
      for (final terminal in [TaskStatus.completed, TaskStatus.cancelled]) {
        expect(taskWith(terminal).isTerminal, isTrue);
        expect(taskWith(terminal).canStart, isFalse);
        expect(taskWith(terminal).canComplete, isFalse);
        expect(taskWith(terminal).canCancel, isFalse);
      }
      expect(taskWith(TaskStatus.todo).isTerminal, isFalse);
    });
  });

  group('Task due label', () {
    test('formats a set due date', () {
      final task = Task(
        id: 't1',
        title: 'T',
        status: TaskStatus.todo,
        dueDate: DateTime(2026, 1, 8),
        overdue: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(task.dueLabel, 'Jan 8, 2026');
    });

    test('reports no due date when unset', () {
      final task = Task(
        id: 't1',
        title: 'T',
        status: TaskStatus.todo,
        overdue: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(task.dueLabel, 'No due date');
    });
  });

  group('TaskPage.fromJson', () {
    test('parses content and pagination metadata', () {
      final page = TaskPage.fromJson({
        'content': [
          {
            'id': 'task-1',
            'title': 'Write the weekly report',
            'status': 'IN_PROGRESS',
            'overdue': true,
            'createdAt': '2026-01-08T09:30:00Z',
            'updatedAt': '2026-01-08T09:30:00Z',
          },
        ],
        'page': 2,
        'size': 15,
        'totalElements': 31,
        'totalPages': 3,
        'first': false,
        'last': false,
      });

      expect(page.tasks, hasLength(1));
      expect(page.page, 2);
      expect(page.pageNumber, 3);
      expect(page.size, 15);
      expect(page.totalElements, 31);
      expect(page.totalPages, 3);
      expect(page.first, isFalse);
      expect(page.last, isFalse);
      expect(page.isEmpty, isFalse);
    });

    test('handles an empty page', () {
      final page = TaskPage.fromJson({
        'content': <Object>[],
        'page': 0,
        'size': 0,
        'totalElements': 0,
        'totalPages': 0,
        'first': true,
        'last': true,
      });
      expect(page.isEmpty, isTrue);
      expect(page.tasks, isEmpty);
      expect(page.pageNumber, 1);
    });
  });

  group('date formatting', () {
    test('formatTaskDate formats without time', () {
      expect(formatTaskDate(DateTime(2026, 1, 8)), 'Jan 8, 2026');
      expect(formatTaskDate(DateTime(2026, 12, 31)), 'Dec 31, 2026');
    });

    test('isoDateString pads month and day', () {
      expect(isoDateString(DateTime(2026, 1, 8)), '2026-01-08');
      expect(isoDateString(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
