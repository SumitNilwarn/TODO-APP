import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';

import '../../support/mock_api.dart';
import '../../support/widget_test_harness.dart';

Future<AuthState> _authenticated(MockApiServer server) async {
  final auth = AuthState(httpClient: server.client);
  await auth.login(username: 'ada', password: 'password123');
  return auth;
}

// The profile card is taller than the default test viewport, so scroll the
// save button into view before tapping it.
Future<void> _save(WidgetTester tester) async {
  // Let any previous snackbar time out so it never covers the button.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final button = find.widgetWithText(FilledButton, 'Save profile');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('ProfilePage', () {
    testWidgets('loads and pre-fills the existing profile', (tester) async {
      final server = MockApiServer();
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/profile');

      expect(server.profileGetCalls, greaterThanOrEqualTo(1));
      expect(find.text('Ada'), findsWidgets);
      expect(find.text('Lovelace'), findsWidgets);
      expect(find.text('Europe/London'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Save profile'), findsOneWidget);
    });

    testWidgets(
      'creates a profile via PUT on first visit, then PATCHes edits',
      (tester) async {
        final server = MockApiServer(behavior: Behavior(profileNotFound: true));
        final auth = await _authenticated(server);
        addTearDown(auth.dispose);
        await pumpApp(tester, auth: auth, initialRoute: '/profile');

        expect(find.text('Create your profile'), findsOneWidget);
        expect(server.profilePutCalls, 0);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'First name'),
          'Grace',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Display name'),
          'Grace',
        );
        await _save(tester);

        expect(server.profilePutCalls, 1);
        expect(server.profilePatchCalls, 0);
        final putBody =
            jsonDecode(server.requests.last.body) as Map<String, dynamic>;
        expect(putBody.keys.toSet(), {
          'firstName',
          'lastName',
          'displayName',
          'timezone',
          'profileImageUrl',
        });
        expect(putBody['firstName'], 'Grace');
        expect(find.text('Profile created.'), findsOneWidget);

        // Editing now uses PATCH with only the changed field.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Display name'),
          'A.L.',
        );
        await _save(tester);

        expect(server.profilePatchCalls, 1);
        final patchBody =
            jsonDecode(server.requests.last.body) as Map<String, dynamic>;
        expect(patchBody.keys.toSet(), {'displayName'});
        expect(patchBody['displayName'], 'A.L.');
        expect(find.text('Profile saved.'), findsOneWidget);
      },
    );

    testWidgets('validates the image URL before touching the network', (
      tester,
    ) async {
      final server = MockApiServer();
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/profile');

      final putsBefore = server.profilePutCalls;
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile image URL'),
        'not-a-url',
      );
      await _save(tester);

      expect(server.profilePutCalls, putsBefore);
      expect(
        find.text(
          'Enter a valid http(s) URL (e.g. https://example.com/image.png).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reports a server error on load with a retry action', (
      tester,
    ) async {
      // A dedicated backend flavour: profile GET fails, PUT would succeed.
      final server = MockApiServer(behavior: Behavior(failProfileGet: true));
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/profile');

      expect(find.text('boom'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('lays out correctly across all supported widths', (
      tester,
    ) async {
      final server = MockApiServer();
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);

      // Phase 16 baseline: every shell width must render the profile editor
      // without overflow errors.
      for (final width in const [390, 600, 768, 1024, 1280, 1440]) {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await pumpApp(tester, auth: auth, initialRoute: '/profile');

        expect(tester.takeException(), isNull);
        expect(
          find.widgetWithText(FilledButton, 'Save profile'),
          findsOneWidget,
        );
        expect(find.text('Europe/London'), findsWidgets);
      }
    });
    testWidgets('reports a failed first-time PUT without leaking a body', (
      tester,
    ) async {
      final server = MockApiServer(
        behavior: Behavior(
          profileNotFound: true,
          failProfilePut: true,
          putCode: 'VALIDATION_ERROR',
        ),
      );
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/profile');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Grace',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Grace',
      );
      await _save(tester);

      expect(server.profilePutCalls, 1);
      expect(
        find.text('Profile could not be saved. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('VALIDATION_ERROR'), findsNothing);
    });

    testWidgets('a conflicting PATCH surfaces the optimistic-lock copy', (
      tester,
    ) async {
      final server = MockApiServer(behavior: Behavior(failProfilePatch: true));
      final auth = await _authenticated(server);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/profile');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'A.L.',
      );
      await _save(tester);

      expect(server.profilePatchCalls, 1);
      expect(
        find.text('Profile was modified by another request'),
        findsOneWidget,
      );
    });
  });
}
