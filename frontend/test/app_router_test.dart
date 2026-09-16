import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';
import 'package:todo_app/features/profile/presentation/profile_page.dart';
import 'package:todo_app/presentation/router/app_router.dart';
import 'package:todo_app/presentation/screens/design_system_page.dart';

import 'support/mock_api.dart';

/// A signed-in [AuthState] backed by the fake backend.
Future<AuthState> authenticatedAuth({MockApiServer? server}) async {
  final auth = AuthState(httpClient: (server ?? MockApiServer()).client);
  final ok = await auth.login(username: 'ada', password: 'password123');
  expect(ok, isTrue);
  return auth;
}

void main() {
  test('route names are centralized, unique and include design-system', () {
    expect(AppRouter.home, '/');
    expect(AppRouter.login, '/login');
    expect(AppRouter.register, '/register');
    expect(AppRouter.profile, '/profile');
    expect(AppRouter.dashboard, '/dashboard');
    expect(AppRouter.tasks, '/tasks');
    expect(AppRouter.designSystem, '/design-system');
    expect(
      {
        AppRouter.home,
        AppRouter.login,
        AppRouter.register,
        AppRouter.profile,
        AppRouter.dashboard,
        AppRouter.tasks,
        AppRouter.designSystem,
      }.length,
      7,
    );
    expect(AppRouter.protectedRoutes, {
      AppRouter.profile,
      AppRouter.dashboard,
      AppRouter.tasks,
    });
  });

  testWidgets('unknown routes fall back to the home page', (tester) async {
    await tester.pumpWidget(const TodoApp(initialRoute: '/does-not-exist'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Todo App'), findsOneWidget);
  });

  testWidgets('anonymous visitors can reach the public login page', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp(initialRoute: AppRouter.login));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('anonymous visitors can reach the public register page', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp(initialRoute: AppRouter.register));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('protected routes redirect anonymous visitors to login', (
    tester,
  ) async {
    for (final route in AppRouter.protectedRoutes) {
      await tester.pumpWidget(
        TodoApp(key: ValueKey(route), initialRoute: route),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sign in'),
        findsOneWidget,
        reason: '$route should land anonymous visitors on the login screen',
      );
    }
  });

  testWidgets('anonymous visitors at a task detail are redirected to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      TodoApp(initialRoute: AppRouter.taskDetailFor('task-1')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('signing in returns an anonymous visitor to the intended route', (
    tester,
  ) async {
    final auth = AuthState(httpClient: MockApiServer().client);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      TodoApp(authState: auth, initialRoute: AppRouter.tasks),
    );
    await tester.pumpAndSettle();

    // The protected guard landed anonymous visitors on login.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'ada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Back on the tasks list, not the landing page.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
    expect(find.text('Your to-do list.'), findsWidgets);
  });

  testWidgets('login redirects authenticated visitors into the app', (
    tester,
  ) async {
    final auth = await authenticatedAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      TodoApp(authState: auth, initialRoute: AppRouter.login),
    );
    await tester.pumpAndSettle();

    // The guard sends signed-in users to the landing page which offers the
    // dashboard for them.
    expect(find.text('Welcome to Todo App'), findsOneWidget);
    expect(find.text('Open dashboard'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('landing page never replaces itself for signed-in visitors', (
    tester,
  ) async {
    final auth = await authenticatedAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      TodoApp(authState: auth, initialRoute: AppRouter.home),
    );
    // The public-only guard aims signed-in callers at the landing page, which
    // is also the current route; it must not try to navigate to itself (that
    // would loop forever and the frame pump would never settle).
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Todo App'), findsOneWidget);
    expect(find.text('Open dashboard'), findsOneWidget);
  });

  testWidgets('authenticated visitors can open their profile', (tester) async {
    final server = MockApiServer();
    final auth = await authenticatedAuth(server: server);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      TodoApp(authState: auth, initialRoute: AppRouter.profile),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);
    expect(server.profileGetCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('design system stays publicly accessible', (tester) async {
    await tester.pumpWidget(
      const TodoApp(initialRoute: AppRouter.designSystem),
    );
    // The inventory showcases a perpetual loading button, so it animates
    // forever; pumpAndSettle would never settle. Bounded pumps are used
    // instead (same convention as design_system_page_test.dart).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DesignSystemPage), findsOneWidget);
  });
}
