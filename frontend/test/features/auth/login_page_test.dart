import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';

import '../../support/mock_api.dart';
import '../../support/widget_test_harness.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('LoginPage', () {
    testWidgets('renders the form, hero and footer copy', (tester) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/login');

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to your workspace.'), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('rejects an empty submission with field errors', (
      tester,
    ) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/login');

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your username or email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('shows a friendly banner when credentials are rejected', (
      tester,
    ) async {
      final auth = AuthState(
        httpClient: MockApiServer(behavior: Behavior(failLogin: true)).client,
      );
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/login');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username or email'),
        'ada',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrong',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invalid username or password. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('shows a spinner while the request is in flight', (
      tester,
    ) async {
      final gate = Completer<void>();
      final server = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          await gate.future;
          return _json({'success': true, 'data': mockTokens}, 200);
        }
        if (request.url.path.endsWith('/auth/me')) {
          return _json({'success': true, 'data': mockUser}, 200);
        }
        return _json({'success': true, 'data': null}, 200);
      });

      final auth = AuthState(httpClient: server);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/login');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username or email'),
        'ada',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('redirects to the home page after a successful login', (
      tester,
    ) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/login');

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

      expect(find.text('Open dashboard'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
    });

    testWidgets('lays out correctly across all supported widths', (
      tester,
    ) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);

      for (final width in const [390, 600, 768, 1024, 1280, 1440]) {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await pumpApp(tester, auth: auth, initialRoute: '/login');

        expect(tester.takeException(), isNull);
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      }
    });
  });
}
