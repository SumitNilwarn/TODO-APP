import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';

import '../../support/mock_api.dart';
import '../../support/widget_test_harness.dart';

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    'grace',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'grace@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirm password'),
    'password123',
  );
}

// The register card is taller than the default 600px test viewport, so scroll
// the submit button into view before tapping it.
Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Create account');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('RegisterPage', () {
    testWidgets('renders the create-account form', (tester) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/register');

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirm password'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
    });

    testWidgets('validates all fields before submitting', (tester) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/register');

      await _submit(tester);

      expect(find.text('Enter a username.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
      expect(find.text('Re-enter your password.'), findsOneWidget);
    });

    testWidgets('flags weak passwords and mismatched confirmation', (
      tester,
    ) async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/register');

      await _fillValidForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'not-the-same',
      );
      await _submit(tester);

      expect(
        find.text('Password must be 10–100 characters long.'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets(
      'returns to the sign-in screen after a successful registration',
      (tester) async {
        final auth = AuthState(httpClient: MockApiServer().client);
        addTearDown(auth.dispose);
        await pumpApp(tester, auth: auth, initialRoute: '/register');

        await _fillValidForm(tester);
        await _submit(tester);

        expect(
          find.text('Account created. Sign in to continue.'),
          findsOneWidget,
        );
        expect(find.text('Welcome back'), findsOneWidget);
      },
    );

    testWidgets('surfaces a friendly message on a taken username', (
      tester,
    ) async {
      final auth = AuthState(
        httpClient: MockApiServer(behavior: Behavior(failRegister: true))
            .client,
      );
      addTearDown(auth.dispose);
      await pumpApp(tester, auth: auth, initialRoute: '/register');

      await _fillValidForm(tester);
      await _submit(tester);

      expect(
        find.text('That username is already taken. Choose another.'),
        findsOneWidget,
      );
      expect(find.text('Create your account'), findsOneWidget);
    });
  });
}
