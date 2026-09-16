import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';
import 'package:todo_app/features/tasks/domain/task_list_query.dart';
import 'package:todo_app/features/tasks/domain/task_models.dart';
import 'package:todo_app/shared/widgets/app_button.dart';
import 'package:todo_app/shared/widgets/app_loading.dart';

import '../../support/mock_api.dart';

const Map<String, dynamic> emptyTasksPage = {
  'content': <Object>[],
  'page': 0,
  'size': 0,
  'totalElements': 0,
  'totalPages': 0,
  'first': true,
  'last': true,
};

Map<String, dynamic> pagedTasks({
  required int page,
  required int totalPages,
  required bool first,
  required bool last,
  required String title,
}) {
  return {
    'content': [
      {
        'id': 'page-task-$page',
        'title': title,
        'description': null,
        'status': 'TODO',
        'dueDate': null,
        'completedAt': null,
        'overdue': false,
        'createdAt': '2026-01-08T09:30:00Z',
        'updatedAt': '2026-01-08T09:30:00Z',
        'version': 1,
      },
    ],
    'page': page,
    'size': 15,
    'totalElements': 31,
    'totalPages': totalPages,
    'first': first,
    'last': last,
  };
}

Future<AuthState> _authenticated(MockApiServer server) async {
  final auth = AuthState(httpClient: server.client);
  await auth.login(username: 'ada', password: 'password123');
  return auth;
}

Future<void> _pump(
  WidgetTester tester,
  MockApiServer server, {
  AuthState? auth,
  required String route,
}) async {
  final session = auth ?? await _authenticated(server);
  if (auth == null) addTearDown(session.dispose);
  await tester.pumpWidget(TodoApp(initialRoute: route, authState: session));
  await tester.pumpAndSettle();
}

Future<void> _pumpTasks(WidgetTester tester, MockApiServer server) =>
    _pump(tester, server, route: '/tasks');

/// Pumps the real app onto the list, then opens the detail of the task whose
/// title is [title].
Future<void> _openDetail(
  WidgetTester tester,
  MockApiServer server,
  String title,
) async {
  await _pumpTasks(tester, server);
  final row = find.text(title);
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  group('TasksPage states', () {
    testWidgets('shows a loading state while the first page is in flight', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(responseDelay: const Duration(seconds: 1)),
      );
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);

      await tester.pumpWidget(TodoApp(initialRoute: '/tasks', authState: auth));
      await tester.pump();

      expect(find.byType(AppLoading), findsOneWidget);
      expect(find.text('Loading your tasks…'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('renders the task list with badges, due dates and totals', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      expect(find.text('Book travel for the summit'), findsOneWidget);
      expect(find.text('Ship the design tokens'), findsOneWidget);
      expect(find.text('Jan 8, 2026'), findsWidgets);
      expect(find.text('No due date'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('6 tasks'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(server.tasksGetCalls, 1);
    });

    testWidgets(
      'shows an empty state with a create action when nothing exists',
      (tester) async {
        final server = MockApiServer(
          behavior: Behavior(tasksPage: emptyTasksPage),
        );
        await _pumpTasks(tester, server);

        expect(find.text('You have no tasks yet'), findsOneWidget);
        expect(
          find.text('Create your first task to get started.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppButton, 'Create task'), findsWidgets);
      },
    );

    testWidgets('a failed load shows a friendly error state and retries', (
      tester,
    ) async {
      final server = MockApiServer(behavior: Behavior(failTasksGet: true));
      await _pumpTasks(tester, server);

      expect(find.text('Could not load your tasks'), findsOneWidget);
      expect(
        find.text('An unexpected server error occurred. Please try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Try again'), findsOneWidget);

      server.behavior.failTasksGet = false;
      await tester.tap(find.widgetWithText(AppButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Book travel for the summit'), findsOneWidget);
      expect(find.text('6 tasks'), findsOneWidget);
    });

    testWidgets('a silent refresh requests the current page again', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.byKey(const Key('tasks-refresh')));
      await tester.pumpAndSettle();

      expect(find.text('Book travel for the summit'), findsOneWidget);
      expect(server.tasksGetCalls, 2);
    });
  });

  group('TasksPage filters and pagination', () {
    testWidgets('a status chip fetches with the status filter', (tester) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();

      expect(server.requests.last.url.queryParameters['status'], 'COMPLETED');
      expect(find.text('Ship the design tokens'), findsOneWidget);
      expect(find.text('Book travel for the summit'), findsNothing);
    });

    testWidgets('Overdue only fetches with the overdue flag', (tester) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.text('Overdue only'));
      await tester.pumpAndSettle();

      expect(server.requests.last.url.queryParameters['overdue'], 'true');
      expect(find.text('Book travel for the summit'), findsOneWidget);
      expect(find.text('Write the weekly report'), findsOneWidget);
      expect(find.text('Prepare sprint retrospective'), findsNothing);
    });

    testWidgets('All clears the filters again', (tester) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      final last = server.requests.last.url.queryParameters;
      expect(last.containsKey('status'), isFalse);
      expect(find.text('Book travel for the summit'), findsOneWidget);
    });

    testWidgets('pagination moves across pages with bounded requests', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(
          tasksPage: pagedTasks(
            page: 0,
            totalPages: 3,
            first: true,
            last: false,
            title: 'Page one task',
          ),
        ),
      );
      await _pumpTasks(tester, server);

      expect(find.text('Page one task'), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);

      server.behavior.tasksPage = pagedTasks(
        page: 1,
        totalPages: 3,
        first: false,
        last: false,
        title: 'Page two task',
      );
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Next'));
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Page two task'), findsOneWidget);
      expect(find.text('Page 2 of 3'), findsOneWidget);
      final nextRequest = server.requests.last.url.queryParameters;
      expect(nextRequest['page'], '1');
      expect(nextRequest['size'], '15');

      server.behavior.tasksPage = pagedTasks(
        page: 2,
        totalPages: 3,
        first: false,
        last: true,
        title: 'Page three task',
      );
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Next'));
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Page three task'), findsOneWidget);
      expect(find.text('Page 3 of 3'), findsOneWidget);
      // Last page disables Next.
      final next = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Next'),
      );
      expect(next.onPressed, isNull);
    });
  });

  group('create task flow', () {
    testWidgets('client validation blocks an empty title before any request', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Create task').last,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
      await tester.pumpAndSettle();

      expect(find.text('Enter a title.'), findsOneWidget);
      expect(server.taskCreateCalls, 0);
    });

    testWidgets(
      'creating a task posts, refreshes the list and shows feedback',
      (tester) async {
        final server = MockApiServer();
        await _pumpTasks(tester, server);

        await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Plan the launch',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'),
          'First milestone',
        );
        await tester.ensureVisible(
          find.widgetWithText(AppButton, 'Create task').last,
        );
        await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
        await tester.pumpAndSettle();

        expect(server.taskCreateCalls, 1);
        final post = server.requests.lastWhere(
          (r) => r.method == 'POST' && r.url.path == '/api/v1/tasks',
        );
        final body = jsonDecode(post.body) as Map<String, dynamic>;
        expect(body, {
          'title': 'Plan the launch',
          'description': 'First milestone',
        });
        expect(find.text('Task created.'), findsOneWidget);
        expect(find.text('Plan the launch'), findsOneWidget);
        expect(find.text('Book travel for the summit'), findsOneWidget);
        expect(find.text('7 tasks'), findsOneWidget);
      },
    );

    testWidgets('an optional blank description maps to null on create', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Quick note',
      );
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Create task').last,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
      await tester.pumpAndSettle();

      final post = server.requests.lastWhere(
        (r) => r.method == 'POST' && r.url.path == '/api/v1/tasks',
      );
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body, {'title': 'Quick note', 'description': null});
    });

    testWidgets(
      'a slow create disables the submit button so double-submits are ignored',
      (tester) async {
        final server = MockApiServer(
          behavior: Behavior(responseDelay: const Duration(seconds: 1)),
        );
        await _pumpTasks(tester, server);

        await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Plan the launch',
        );
        await tester.ensureVisible(
          find.widgetWithText(AppButton, 'Create task').last,
        );

        // First tap kicks off the (slow) POST; the form is now in flight, so
        // the submit's label is replaced by a loading spinner and it can no
        // longer be pressed.
        await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
        await tester.pump(const Duration(milliseconds: 200));

        final submit = tester.widget<AppButton>(find.byType(AppButton).last);
        expect(submit.onPressed, isNull);

        // A second tap therefore cannot schedule another POST.
        await tester.tap(find.byType(AppButton).last, warnIfMissed: false);
        // Let the (1s) POST finish and any follow-up refresh it spawns so no
        // timer is left pending at teardown.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(server.taskCreateCalls, 1);
        expect(find.text('Task created.'), findsOneWidget);
      },
    );

    testWidgets(
      'a failed create surfaces field errors inline and keeps the form',
      (tester) async {
        final server = MockApiServer(
          behavior: Behavior(
            failCreateTask: true,
            createTaskStatus: 400,
            createTaskCode: 'VALIDATION_ERROR',
            createTaskDetails: const [
              {'field': 'title', 'message': 'Title is still too long.'},
            ],
          ),
        );
        await _pumpTasks(tester, server);

        await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'A title that the server rejects',
        );
        await tester.ensureVisible(
          find.widgetWithText(AppButton, 'Create task').last,
        );
        await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
        await tester.pumpAndSettle();

        expect(find.text('Title is still too long.'), findsOneWidget);
        // Still on the form — no navigation happened.
        expect(find.widgetWithText(AppButton, 'Save changes'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Create task'), findsOneWidget);
      },
    );

    testWidgets('a server error on create shows a safe general message', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(
          failCreateTask: true,
          createTaskStatus: 500,
          createTaskCode: 'SERVER_ERROR',
          createTaskMessage: 'tasks boom',
        ),
      );
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Do not sink',
      );
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Create task').last,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
      await tester.pumpAndSettle();

      expect(
        find.text('An unexpected server error occurred. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a picked due date is sent as a date-only value', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(AppButton, 'Create task').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set a due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(
        find.text(formatTaskDate(DateTime(now.year, now.month, now.day))),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'With a deadline',
      );
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Create task').last,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Create task').last);
      await tester.pumpAndSettle();

      final post = server.requests.lastWhere(
        (r) => r.method == 'POST' && r.url.path == '/api/v1/tasks',
      );
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(
        body['dueDate'],
        isoDateString(DateTime(now.year, now.month, now.day)),
      );
    });
  });

  group('task detail', () {
    testWidgets('renders title, description, status, due date and metadata', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      final row = find.text('Book travel for the summit');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Book travel for the summit'), findsWidgets);
      expect(
        find.text('Hotel and flights for the February summit.'),
        findsOneWidget,
      );
      expect(find.text('To do'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Jan 8, 2026'), findsOneWidget);
      expect(find.text('Due date'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('a TODO task offers Start, Complete and Cancel', (
      tester,
    ) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Sketch the onboarding flow');

      expect(find.widgetWithText(AppButton, 'Start'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Complete'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel task'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Delete'), findsOneWidget);
    });

    testWidgets('Start moves a TODO task into progress', (tester) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Sketch the onboarding flow');

      await tester.tap(find.widgetWithText(AppButton, 'Start'));
      await tester.pumpAndSettle();

      expect(server.taskStatusCalls, 1);
      expect(server.requests.last.url.path, '/api/v1/tasks/task-4/status');
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body, {'status': 'IN_PROGRESS'});
      expect(find.text('Task started.'), findsOneWidget);
      expect(find.text('In progress'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Start'), findsNothing);
    });

    testWidgets('Complete marks the task done via the lifecycle endpoint', (
      tester,
    ) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Complete'));
      await tester.pumpAndSettle();

      expect(server.taskCompleteCalls, 1);
      expect(server.requests.last.url.path, '/api/v1/tasks/task-1/complete');
      expect(find.text('Task completed.'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Complete'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Cancel task'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);
    });

    testWidgets('Cancel requires confirmation and cancels when confirmed', (
      tester,
    ) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Cancel task'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel task'), findsWidgets);
      expect(
        find.textContaining('will be marked as cancelled'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Cancel task').last);
      await tester.pumpAndSettle();

      expect(server.taskCancelCalls, 1);
      expect(server.requests.last.url.path, '/api/v1/tasks/task-1/cancel');
      expect(find.text('Task cancelled.'), findsOneWidget);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('declining the cancellation makes no request', (tester) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Cancel task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.taskCancelCalls, 0);
      expect(find.text('In progress'), findsWidgets);
    });

    testWidgets(
      'a terminal task hides lifecycle actions but keeps edit/delete',
      (tester) async {
        final server = MockApiServer();
        await _openDetail(tester, server, 'Ship the design tokens');

        expect(find.text('Completed'), findsWidgets);
        expect(find.widgetWithText(AppButton, 'Start'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Complete'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Cancel task'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Delete'), findsOneWidget);
      },
    );

    testWidgets(
      'Delete asks for confirmation, deletes and refreshes the list',
      (tester) async {
        final server = MockApiServer();
        await _openDetail(tester, server, 'Write the weekly report');

        await tester.tap(find.widgetWithText(AppButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('This action cannot be undone.'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(AppButton, 'Delete task'));
        await tester.pumpAndSettle();

        expect(server.taskDeleteCalls, 1);
        expect(find.text('Task deleted.'), findsOneWidget);
        // Back on the list: the row is gone and the count dropped.
        expect(find.text('Write the weekly report'), findsNothing);
        expect(find.text('5 tasks'), findsOneWidget);
      },
    );

    testWidgets('declining delete keeps the task', (tester) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.taskDeleteCalls, 0);
      expect(find.text('In progress'), findsWidgets);
    });
  });

  group('editing a task', () {
    testWidgets('edits patch only the changed fields', (tester) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Write the monthly report',
      );
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(server.taskPatchCalls, 1);
      expect(server.requests.last.url.path, '/api/v1/tasks/task-1');
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'title'});

      expect(find.text('Task updated.'), findsOneWidget);
      expect(find.text('Write the monthly report'), findsWidgets);
    });

    testWidgets('clearing an optional field sends an explicit null', (
      tester,
    ) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        '',
      );
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Save changes'));
      await tester.pumpAndSettle();

      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'description'});
      expect(body['description'], isNull);
    });

    testWidgets('No changes to save stays put and shows info', (tester) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Edit'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(server.taskPatchCalls, 0);
      expect(find.text('No changes to save.'), findsOneWidget);
    });

    testWidgets('clearing the due date patches an explicit null', (
      tester,
    ) async {
      final server = MockApiServer();
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear date'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Save changes'));
      await tester.pumpAndSettle();

      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'dueDate'});
      expect(body['dueDate'], isNull);
    });

    testWidgets(
      'an optimistic-lock conflict keeps the form open with recovery copy',
      (tester) async {
        final server = MockApiServer(
          behavior: Behavior(optimisticLockOnPatch: true),
        );
        await _openDetail(tester, server, 'Write the weekly report');

        await tester.tap(find.widgetWithText(AppButton, 'Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Concurrent edit',
        );
        await tester.ensureVisible(
          find.widgetWithText(AppButton, 'Save changes'),
        );
        await tester.tap(find.widgetWithText(AppButton, 'Save changes'));
        await tester.pumpAndSettle();

        expect(find.textContaining('changed elsewhere'), findsOneWidget);
        expect(
          find.textContaining('Refresh to get the latest version'),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppButton, 'Save changes'), findsOneWidget);
      },
    );
  });

  group('task detail failures', () {
    testWidgets('a missing task shows a friendly 404 state', (tester) async {
      final server = MockApiServer(behavior: Behavior(missingTask: true));
      await _pump(tester, server, route: '/tasks/task-1');

      expect(find.text('Could not load this task'), findsOneWidget);
      expect(find.textContaining('may have been deleted'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Try again'), findsOneWidget);
    });

    testWidgets('an illegal lifecycle move shows recovery copy with Refresh', (
      tester,
    ) async {
      final server = MockApiServer(behavior: Behavior(failCompleteTask: true));
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Complete'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("isn't allowed for this task's current status"),
        findsOneWidget,
      );
      // The snackbar offers a Refresh action to recover.
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('a failed delete shows a safe message and keeps the task', (
      tester,
    ) async {
      final server = MockApiServer(behavior: Behavior(failDeleteTask: true));
      await _openDetail(tester, server, 'Write the weekly report');

      await tester.tap(find.widgetWithText(AppButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Delete task'));
      await tester.pumpAndSettle();

      expect(
        find.text('An unexpected server error occurred. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('In progress'), findsWidgets);
    });
  });

  group('TasksPage search', () {
    testWidgets('typing debounces and fetches with the search parameter', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);
      expect(server.tasksGetCalls, 1);

      await tester.enterText(find.byType(TextField), 'weekly');
      await tester.pump(const Duration(milliseconds: 299));
      expect(server.tasksGetCalls, 1, reason: 'Wait for the debounce window');
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();

      expect(server.tasksGetCalls, 2);
      expect(server.requests.last.url.queryParameters['search'], 'weekly');
      expect(find.text('Write the weekly report'), findsOneWidget);
    });

    testWidgets('a rapid burst coalesces into a single request', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      for (final text in ['a', 'ab', 'abc']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(server.tasksGetCalls, 2);
      expect(server.requests.last.url.queryParameters['search'], 'abc');
    });

    testWidgets('the clear button empties search and refetches', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.enterText(find.byType(TextField), 'weekly');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(server.requests.last.url.queryParameters['search'], 'weekly');

      await tester.tap(find.byKey(const Key('search-clear')));
      await tester.pumpAndSettle();

      final params = server.requests.last.url.queryParameters;
      expect(params.containsKey('search'), isFalse);
      expect(find.text('Book travel for the summit'), findsOneWidget);
    });

    testWidgets('a search with no matches shows a dedicated empty state', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.enterText(find.byType(TextField), 'zzz-never-matches');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('No tasks match your search'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Clear search'), findsOneWidget);
    });

    testWidgets('clearing search from the empty state restores the list', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.enterText(find.byType(TextField), 'zzz-never-matches');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No tasks match your search'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('Book travel for the summit'), findsOneWidget);
      expect(find.text('6 tasks'), findsOneWidget);
    });

    testWidgets('search survives status filter changes and clears alone', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.enterText(find.byType(TextField), 'report');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'In progress'));
      await tester.pumpAndSettle();

      var params = server.requests.last.url.queryParameters;
      expect(params['search'], 'report');
      expect(params['status'], 'IN_PROGRESS');
      expect(find.text('Write the weekly report'), findsOneWidget);

      await tester.tap(find.byKey(const Key('search-clear')));
      await tester.pumpAndSettle();

      params = server.requests.last.url.queryParameters;
      expect(params.containsKey('search'), isFalse);
      expect(params['status'], 'IN_PROGRESS');
    });

    testWidgets('the search field caps input at the backend limit of 200', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);
      expect(server.tasksGetCalls, 1);

      await tester.enterText(find.byType(TextField), 'x' * 300);
      await tester.pump(const Duration(milliseconds: 299));
      expect(server.tasksGetCalls, 1, reason: 'Wait for the debounce window');
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();

      final search = server.requests.last.url.queryParameters['search']!;
      expect(
        search,
        'x' * 200,
        reason: 'field must match the TaskService MAX_SEARCH_LENGTH',
      );
      expect(search.length, lessThanOrEqualTo(200));
    });
  });

  group('TasksPage filters and sort', () {
    testWidgets('combined status and overdue filters are sent together', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue only'));
      await tester.pumpAndSettle();

      final params = server.requests.last.url.queryParameters;
      expect(params['status'], 'COMPLETED');
      expect(params['overdue'], 'true');
      expect(find.text('No tasks match your current filters'), findsOneWidget);
    });

    testWidgets('the sort dropdown forwards the chosen field and resets page', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.byType(DropdownButton<TaskSortField>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Title'));
      await tester.pumpAndSettle();

      final params = server.requests.last.url.queryParameters;
      expect(params['sort'], 'title');
      expect(params['page'], '0');
    });

    testWidgets('the direction toggle flips ASC and DESC', (tester) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.byKey(const Key('sort-direction')));
      await tester.pumpAndSettle();
      expect(server.requests.last.url.queryParameters['direction'], 'ASC');

      await tester.tap(find.byKey(const Key('sort-direction')));
      await tester.pumpAndSettle();
      expect(server.requests.last.url.queryParameters['direction'], 'DESC');
    });

    testWidgets('a filter change after pagination resets to page 0', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(
          tasksPage: pagedTasks(
            page: 0,
            totalPages: 3,
            first: true,
            last: false,
            title: 'Page one task',
          ),
        ),
      );
      await _pumpTasks(tester, server);

      server.behavior.tasksPage = pagedTasks(
        page: 1,
        totalPages: 3,
        first: false,
        last: false,
        title: 'Page two task',
      );
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Next'));
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();
      expect(server.requests.last.url.queryParameters['page'], '1');

      final completed = find.widgetWithText(ChoiceChip, 'Completed');
      await tester.ensureVisible(completed);
      await tester.tap(completed);
      await tester.pumpAndSettle();

      final params = server.requests.last.url.queryParameters;
      expect(params['page'], '0');
      expect(params['status'], 'COMPLETED');
    });

    testWidgets('clear filters drops search and status but keeps sorting', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.enterText(find.byType(TextField), 'report');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'In progress'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clear-filters')));
      await tester.pumpAndSettle();

      final params = server.requests.last.url.queryParameters;
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('status'), isFalse);
      expect(params.containsKey('overdue'), isFalse);
      expect(params['sort'], 'createdAt');
      expect(find.text('6 tasks'), findsOneWidget);
    });
  });

  group('TasksPage date range', () {
    testWidgets('picking from and to sends inclusive bounds', (tester) async {
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      await tester.tap(find.text('Due date'));
      await tester.pumpAndSettle();
      expect(find.text('Due date range'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Apply'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final params = server.requests.last.url.queryParameters;
      expect(
        params['dueDateFrom'],
        isoDateString(DateTime(now.year, now.month, 10)),
      );
      expect(
        params['dueDateTo'],
        isoDateString(DateTime(now.year, now.month, 20)),
      );
      // Fixture due dates are in the past, so the bounds match nothing.
      expect(find.text('No tasks match your current filters'), findsOneWidget);
    });

    testWidgets('clearing dates removes the bounds and refetches', (
      tester,
    ) async {
      // A fixed page keeps content on screen so the date chip stays reachable
      // even after the (fixture-matching-nothing) range is applied.
      final server = MockApiServer(
        behavior: Behavior(
          tasksPage: pagedTasks(
            page: 0,
            totalPages: 1,
            first: true,
            last: true,
            title: 'Fixed task',
          ),
        ),
      );
      await _pumpTasks(tester, server);

      await tester.tap(find.text('Due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(
        server.requests.last.url.queryParameters.containsKey('dueDateFrom'),
        isTrue,
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear dates'));
      await tester.pumpAndSettle();

      final params = server.requests.last.url.queryParameters;
      expect(params.containsKey('dueDateFrom'), isFalse);
      expect(params.containsKey('dueDateTo'), isFalse);
      expect(find.text('Fixed task'), findsOneWidget);
    });

    testWidgets(
      'a from-after-to range shows an inline error and skips the fetch',
      (tester) async {
        final server = MockApiServer();
        await _pumpTasks(tester, server);

        await tester.tap(find.text('Due date'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'From'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('20'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'To'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('8'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(AppButton, 'Apply'));
        await tester.pumpAndSettle();

        expect(
          find.text('Start date must not be after end date.'),
          findsOneWidget,
        );
        expect(server.tasksGetCalls, 1);
      },
    );
  });

  group('tasks responsiveness and accessibility', () {
    testWidgets('list and detail never overflow across target widths', (
      tester,
    ) async {
      final server = MockApiServer();
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);

      for (final width in const [390, 600, 768, 1024, 1280, 1440]) {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          TodoApp(initialRoute: '/tasks', authState: auth),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Task list at ${width}px',
        );

        await tester.pumpWidget(
          TodoApp(initialRoute: '/tasks/task-1', authState: auth),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Task detail at ${width}px',
        );
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('primary actions are exposed to assistive technology', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final server = MockApiServer();
      await _pumpTasks(tester, server);

      expect(find.bySemanticsLabel('Create task'), findsWidgets);
      // Icon buttons are exposed to assistive technology through their tooltip.
      expect(find.byTooltip('Refresh tasks'), findsOneWidget);
      await _openDetail(tester, server, 'Sketch the onboarding flow');
      expect(find.bySemanticsLabel('Complete'), findsWidgets);
      expect(find.bySemanticsLabel('Back to tasks'), findsWidgets);
      semantics.dispose();
    });
  });
}
