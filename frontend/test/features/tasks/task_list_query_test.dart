import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/tasks/domain/task_list_query.dart';
import 'package:todo_app/features/tasks/domain/task_models.dart';

void main() {
  group('TaskSortField', () {
    test('maps every field to the backend allowlist', () {
      expect(TaskSortField.values, hasLength(5));
      expect(TaskSortField.values.map((f) => f.apiValue), [
        'createdAt',
        'updatedAt',
        'dueDate',
        'title',
        'status',
      ]);
    });

    test('labels are user-facing and unique', () {
      final labels = TaskSortField.values.map((f) => f.label).toSet();
      expect(labels, hasLength(TaskSortField.values.length));
      for (final field in TaskSortField.values) {
        expect(field.label, isNotEmpty);
      }
    });
  });

  group('TaskListQuery defaults', () {
    test('defaults to page 0, size, createdAt DESC and no filters', () {
      const query = TaskListQuery();
      expect(query.page, 0);
      expect(query.size, kTaskPageSize);
      expect(query.sort, TaskSortField.createdAt);
      expect(query.direction, 'DESC');
      expect(query.status, isNull);
      expect(query.dueDateFrom, isNull);
      expect(query.dueDateTo, isNull);
      expect(query.overdue, isFalse);
      expect(query.search, isEmpty);
      expect(query.hasActiveFilters, isFalse);
      expect(query.activeFilterCount, 0);
    });

    test('toQueryParams only sends non-default values', () {
      final params = const TaskListQuery().toQueryParams();
      expect(params, {
        'page': '0',
        'size': '$kTaskPageSize',
        'sort': 'createdAt',
        'direction': 'DESC',
      });
      expect(params.containsKey('status'), isFalse);
      expect(params.containsKey('overdue'), isFalse);
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('dueDateFrom'), isFalse);
      expect(params.containsKey('dueDateTo'), isFalse);
    });

    test('overdue=false is never sent', () {
      const query = TaskListQuery(overdue: false);
      final params = query.toQueryParams();
      expect(params.containsKey('overdue'), isFalse);
    });
  });

  group('TaskListQuery serialization', () {
    test('includes every set filter with the exact wire format', () {
      final query = TaskListQuery(
        page: 2,
        size: 50,
        sort: TaskSortField.title,
        direction: 'ASC',
        status: TaskStatus.completed,
        dueDateFrom: DateTime(2026, 1, 8),
        dueDateTo: DateTime(2026, 1, 31),
        overdue: true,
        search: '  monthly  ',
      );
      expect(query.toQueryParams(), {
        'page': '2',
        'size': '50',
        'sort': 'title',
        'direction': 'ASC',
        'status': 'COMPLETED',
        'dueDateFrom': '2026-01-08',
        'dueDateTo': '2026-01-31',
        'overdue': 'true',
        'search': 'monthly',
      });
    });

    test('trims search and drops a whitespace-only search', () {
      final query = const TaskListQuery(search: '   ').toQueryParams();
      expect(query.containsKey('search'), isFalse);

      final trimmed = const TaskListQuery(search: '  weekly  ').toQueryParams();
      expect(trimmed['search'], 'weekly');
    });
  });

  group('TaskListQuery copyWith and reset', () {
    test('copyWith overwrites only non-null params', () {
      const base = TaskListQuery();
      final next = base.copyWith(page: 3, sort: TaskSortField.dueDate);
      expect(next.page, 3);
      expect(next.sort, TaskSortField.dueDate);
      expect(next.size, kTaskPageSize);
      expect(next.direction, 'DESC');
      expect(next.status, isNull);
    });

    test('copyWith can clear status and due dates via nullable functions', () {
      final query = TaskListQuery(
        status: TaskStatus.todo,
        dueDateFrom: DateTime(2026, 1, 1),
        dueDateTo: DateTime(2026, 1, 15),
      );
      final cleared = query.copyWith(
        status: () => null,
        dueDateFrom: () => null,
        dueDateTo: () => null,
      );
      expect(cleared.status, isNull);
      expect(cleared.dueDateFrom, isNull);
      expect(cleared.dueDateTo, isNull);
      expect(cleared.page, 0);
    });

    test('resetPage returns a query on page 0', () {
      const query = TaskListQuery(page: 5);
      expect(query.resetPage().page, 0);
    });

    test('clearFilters clears filters while keeping sort and direction', () {
      final query = TaskListQuery(
        page: 4,
        sort: TaskSortField.title,
        direction: 'ASC',
        status: TaskStatus.inProgress,
        dueDateFrom: DateTime(2026, 1, 1),
        overdue: true,
        search: 'hello',
      );
      final cleared = query.clearFilters();
      expect(cleared.search, isEmpty);
      expect(cleared.status, isNull);
      expect(cleared.dueDateFrom, isNull);
      expect(cleared.dueDateTo, isNull);
      expect(cleared.overdue, isFalse);
      expect(cleared.page, 0);
      expect(cleared.sort, TaskSortField.title);
      expect(cleared.direction, 'ASC');
      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.activeFilterCount, 0);
    });
  });

  group('TaskListQuery active filter accounting', () {
    test('hasActiveFilters and activeFilterCount track every filter', () {
      expect(const TaskListQuery(search: 'x').activeFilterCount, 1);
      expect(
        TaskListQuery(
          search: 'x',
          status: TaskStatus.todo,
          dueDateFrom: DateTime(2026),
          dueDateTo: DateTime(2026, 1, 2),
          overdue: true,
        ).activeFilterCount,
        5,
      );
      expect(
        const TaskListQuery(
          sort: TaskSortField.title,
          direction: 'ASC',
        ).hasActiveFilters,
        isFalse,
      );
    });
  });

  group('TaskListQuery equality', () {
    test('equal values compare equal; dates compare by calendar day', () {
      final a = TaskListQuery(
        dueDateFrom: DateTime(2026, 1, 8, 14, 30),
        search: 'x',
      );
      final b = TaskListQuery(
        dueDateFrom: DateTime(2026, 1, 8, 9),
        search: 'x',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing filters break equality', () {
      const base = TaskListQuery();
      expect(base, const TaskListQuery());
      expect(
        base.copyWith(status: () => TaskStatus.completed),
        isNot(const TaskListQuery()),
      );
      expect(base.copyWith(page: 1), isNot(const TaskListQuery()));
      expect(base.copyWith(overdue: true), isNot(const TaskListQuery()));
    });
  });
}
