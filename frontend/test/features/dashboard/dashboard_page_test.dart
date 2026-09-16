import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';
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

const Map<String, dynamic> lonelyDashboard = {
  'totalTasks': 1,
  'todoTasks': 1,
  'inProgressTasks': 0,
  'completedTasks': 0,
  'cancelledTasks': 0,
  'overdueTasks': 0,
};

const Map<String, dynamic> zeroDashboard = {
  'totalTasks': 0,
  'todoTasks': 0,
  'inProgressTasks': 0,
  'completedTasks': 0,
  'cancelledTasks': 0,
  'overdueTasks': 0,
};

Future<AuthState> _authenticated(MockApiServer server) async {
  final auth = AuthState(httpClient: server.client);
  await auth.login(username: 'ada', password: 'password123');
  return auth;
}

/// Pumps the real app on the dashboard route for a freshly authenticated
/// session backed by [server] and settles.
Future<void> _pumpDashboard(
  WidgetTester tester,
  MockApiServer server, {
  AuthState? auth,
}) async {
  final session = auth ?? await _authenticated(server);
  if (auth == null) addTearDown(session.dispose);
  await tester.pumpWidget(
    TodoApp(initialRoute: '/dashboard', authState: session),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DashboardPage states', () {
    testWidgets('shows a loading state right after mounting', (tester) async {
      final server = MockApiServer();
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        TodoApp(initialRoute: '/dashboard', authState: auth),
      );

      expect(find.byType(AppLoading), findsOneWidget);
      expect(find.text('Loading your dashboard…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(AppLoading), findsNothing);
    });

    testWidgets('renders metrics, status bars, overdue and task previews', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpDashboard(tester, server);

      expect(server.dashboardGetCalls, greaterThanOrEqualTo(1));
      expect(server.tasksGetCalls, greaterThanOrEqualTo(3));

      // Metric tiles announce label + count to screen readers.
      final handle = tester.ensureSemantics();
      for (final label in const [
        'Total, 8',
        'To do, 3',
        'In progress, 2',
        'Completed, 2',
        'Cancelled, 1',
        'Overdue, 3',
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: 'missing metric $label',
        );
      }
      handle.dispose();

      // Status breakdown section.
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Your tasks by status'), findsOneWidget);

      // Overdue section lists the two overdue fixture tasks.
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Write the weekly report'), findsWidgets);
      expect(find.text('Book travel for the summit'), findsWidgets);
      expect(find.text("You're all caught up"), findsNothing);

      // Task rows surface a concise description when the backend provides one.
      expect(
        find.text('Hotel and flights for the February summit.'),
        findsWidgets,
      );

      // Task previews.
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('Nothing scheduled'), findsOneWidget);
      expect(find.text('View all tasks'), findsOneWidget);
    });

    testWidgets('shows a safe error state with retry when the summary fails', (
      tester,
    ) async {
      final server = MockApiServer(behavior: Behavior(failDashboardGet: true));
      await _pumpDashboard(tester, server);

      expect(find.text('Could not load your dashboard'), findsOneWidget);
      expect(find.textContaining('unexpected server error'), findsOneWidget);
      expect(find.text('dashboard boom'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('shows a safe error state when a task list fails', (
      tester,
    ) async {
      final server = MockApiServer(behavior: Behavior(failTasksGet: true));
      await _pumpDashboard(tester, server);

      expect(find.text('Could not load your dashboard'), findsOneWidget);
      expect(find.textContaining('unexpected server error'), findsOneWidget);
      expect(find.text('tasks boom'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('shows a permission message without leaking a 403 body', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(
          failDashboardGet: true,
          dashboardErrorStatus: 403,
          dashboardErrorCode: 'ACCESS_DENIED',
          dashboardErrorMessage: 'Access denied by policy',
        ),
      );
      await _pumpDashboard(tester, server);

      expect(find.textContaining("don't have permission"), findsOneWidget);
      expect(find.text('Access denied by policy'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retry reloads and renders the dashboard', (tester) async {
      final server = MockApiServer(behavior: Behavior(failDashboardGet: true));
      await _pumpDashboard(tester, server);

      server.behavior.failDashboardGet = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load your dashboard'), findsNothing);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('empty dashboard surfaces the per-section empty states', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(
          dashboard: lonelyDashboard,
          tasksPage: emptyTasksPage,
        ),
      );
      await _pumpDashboard(tester, server);

      expect(find.text("You're all caught up"), findsWidgets);
      expect(find.text('You have no tasks yet'), findsOneWidget);
      expect(find.text('Nothing scheduled'), findsOneWidget);
    });

    testWidgets('a fully empty workspace shows the breakdown empty state', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(dashboard: zeroDashboard, tasksPage: emptyTasksPage),
      );
      await _pumpDashboard(tester, server);

      expect(find.text('No tasks yet'), findsOneWidget);
      expect(
        find.text('Create tasks to see a live breakdown here.'),
        findsOneWidget,
      );
    });
  });

  group('DashboardPage filters and actions', () {
    testWidgets('a status chip re-queries tasks with that status', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpDashboard(tester, server);

      final chip = find.widgetWithText(ChoiceChip, 'To do');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final withStatus = server.requests.where(
        (r) =>
            r.url.path.endsWith('/tasks') &&
            r.url.queryParameters['status'] == 'TODO',
      );
      expect(withStatus, isNotEmpty, reason: 'recent re-query sends status');
      // Completed tasks leave the recent preview after filtering.
      expect(find.text('Ship the design tokens'), findsNothing);
    });

    testWidgets('the overdue-only chip re-queries with overdue=true', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpDashboard(tester, server);

      final chip = find.widgetWithText(FilterChip, 'Overdue only');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final withOverdue = server.requests.where(
        (r) =>
            r.url.path.endsWith('/tasks') &&
            r.url.queryParameters['overdue'] == 'true',
      );
      expect(withOverdue, isNotEmpty, reason: 'recent re-query sends overdue');
      expect(find.text('Ship the design tokens'), findsNothing);
    });

    testWidgets('a second refresh is refused while one is in flight', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(responseDelay: const Duration(seconds: 1)),
      );
      await _pumpDashboard(tester, server);

      final dashboardBefore = server.dashboardGetCalls;
      final tasksBefore = server.tasksGetCalls;

      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('dashboard-refresh')))
            .onPressed,
        isNull,
        reason: 'refresh must be disabled while a refresh is in flight',
      );

      // A tap on the disabled action must not start a duplicate round-trip.
      await tester.tap(
        find.byKey(const Key('dashboard-refresh')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(server.dashboardGetCalls, dashboardBefore + 1);
      expect(server.tasksGetCalls, tasksBefore + 3);
    });

    testWidgets('a filter change during an in-flight refresh is not dropped', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(responseDelay: const Duration(seconds: 1)),
      );
      await _pumpDashboard(tester, server);

      // Start a refresh and apply a status filter while it is still running.
      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pump();
      await tester.pump();

      final chip = find.widgetWithText(ChoiceChip, 'To do');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();

      await tester.pumpAndSettle();

      // The queued refresh must re-query with the new status...
      final withStatus = server.requests.where(
        (r) =>
            r.url.path.endsWith('/tasks') &&
            r.url.queryParameters['status'] == 'TODO',
      );
      expect(
        withStatus,
        isNotEmpty,
        reason: 'filter change during a refresh must not be dropped',
      );
      // ...and the recent preview settles on the filtered view.
      expect(find.text('Ship the design tokens'), findsNothing);
    });

    testWidgets('refreshing keeps content on screen and updates the data', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpDashboard(tester, server);

      final dashboardCallsBefore = server.dashboardGetCalls;
      final tasksCallsBefore = server.tasksGetCalls;

      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pumpAndSettle();

      expect(server.dashboardGetCalls, greaterThan(dashboardCallsBefore));
      expect(server.tasksGetCalls, greaterThan(tasksCallsBefore));
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps content and shows a snackbar', (
      tester,
    ) async {
      final server = MockApiServer();
      await _pumpDashboard(tester, server);

      server.behavior.failTasksGet = true;
      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Refresh failed'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // Let the snackbar time out so the test ends fully settled.
      await tester.pumpAndSettle();
    });

    testWidgets('View all tasks navigates to the tasks route', (tester) async {
      final server = MockApiServer();
      await _pumpDashboard(tester, server);

      final viewAll = find.text('View all tasks');
      await tester.ensureVisible(viewAll);
      await tester.tap(viewAll);
      await tester.pumpAndSettle();

      // The tasks route now hosts the real task list (Phase 13).
      expect(find.text('Book travel for the summit'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(find.text('Create task'), findsWidgets);
    });
  });

  group('DashboardPage responsiveness', () {
    testWidgets('never overflows across target widths', (tester) async {
      final server = MockApiServer();
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);

      for (final width in const [390, 600, 768, 1024, 1280, 1440]) {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          TodoApp(initialRoute: '/dashboard', authState: auth),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Dashboard at ${width}px',
        );
        expect(find.text('Total'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
