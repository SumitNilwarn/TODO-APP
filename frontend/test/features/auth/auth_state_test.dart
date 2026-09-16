import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/auth/domain/auth_models.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';

import '../../support/mock_api.dart';

void main() {
  group('AuthState — lifecycle', () {
    test('initialise reports unauthenticated when no session exists', () async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      expect(auth.status, AuthStatus.unknown);

      await auth.initialise();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.accessToken, isNull);
    });

    test('login loads tokens and the current user', () async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);

      final ok = await auth.login(username: 'ada', password: 'password123');

      expect(ok, isTrue);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.username, 'ada');
      expect(auth.user?.email, 'ada@example.com');
      expect(auth.accessToken, mockTokens['accessToken']);
      expect(auth.refreshToken, isNotNull);
      expect(auth.lastError, isNull);
    });

    test(
      'failed login clears any session and records a friendly error',
      () async {
        final auth = AuthState(
          httpClient: MockApiServer(behavior: Behavior(failLogin: true)).client,
        );
        addTearDown(auth.dispose);

        final ok = await auth.login(username: 'ada', password: 'bad');

        expect(ok, isFalse);
        expect(auth.status, AuthStatus.unauthenticated);
        expect(auth.accessToken, isNull);
        expect(
          auth.lastError,
          'Invalid username or password. Please try again.',
        );
      },
    );

    test('locked accounts surface a specific message', () async {
      final auth = AuthState(
        httpClient: MockApiServer(
          behavior: Behavior(
            failLogin: true,
            loginCode: 'ACCOUNT_LOCKED',
            loginMessage: 'Locked',
          ),
        ).client,
      );
      addTearDown(auth.dispose);

      await auth.login(username: 'ada', password: 'bad');
      expect(auth.lastError, 'This account has been locked.');
    });

    test('validation details are joined into the error banner', () async {
      final auth = AuthState(
        httpClient: MockApiServer(
          behavior: Behavior(
            failLogin: true,
            loginCode: 'VALIDATION_ERROR',
            loginDetails: [
              {'field': 'username', 'message': 'username must not be blank'},
              {'field': 'password', 'message': 'password must not be blank'},
            ],
          ),
        ).client,
      );
      addTearDown(auth.dispose);

      await auth.login(username: '', password: '');
      expect(
        auth.lastError,
        'username must not be blank password must not be blank',
      );
    });

    test(
      'register success clears the error and stays unauthenticated',
      () async {
        final auth = AuthState(httpClient: MockApiServer().client);
        addTearDown(auth.dispose);

        final ok = await auth.register(
          username: 'ada',
          email: 'ada@example.com',
          password: 'password123',
        );

        expect(ok, isTrue);
        expect(auth.status, AuthStatus.unauthenticated);
        expect(auth.lastError, isNull);
        expect(auth.accessToken, isNull);
      },
    );

    test('register conflict surfaces the friendly message', () async {
      final auth = AuthState(
        httpClient: MockApiServer(behavior: Behavior(failRegister: true))
            .client,
      );
      addTearDown(auth.dispose);

      final ok = await auth.register(
        username: 'taken',
        email: 'taken@example.com',
        password: 'password123',
      );

      expect(ok, isFalse);
      expect(auth.lastError, 'That username is already taken. Choose another.');
    });
  });

  group('AuthState — refresh', () {
    test('initialise re-validates a live in-memory session', () async {
      final auth = AuthState(httpClient: MockApiServer().client);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      await auth.initialise();

      expect(auth.status, AuthStatus.authenticated);
      expect(auth.username, 'ada');
    });

    test('concurrent refreshes share a single in-flight rotation', () async {
      final server = MockApiServer();
      final auth = AuthState(httpClient: server.client);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      final results = await Future.wait([
        auth.attemptRefresh(),
        auth.attemptRefresh(),
        auth.attemptRefresh(),
      ]);

      expect(results, everyElement(isTrue));
      // One rotation only — the single-use refresh token is never raced.
      expect(server.refreshCalls, 1);
    });

    test('a failed refresh clears the session', () async {
      // Login with a refresh token the fake backend rejects on rotation.
      final server = MockApiServer(
        behavior: Behavior(
          tokens: {
            'accessToken': 'access-1',
            'refreshToken': 'refresh-expired',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
          },
        ),
      );
      final auth = AuthState(httpClient: server.client);
      addTearDown(auth.dispose);
      expect(
        await auth.login(username: 'ada', password: 'password123'),
        isTrue,
      );

      final refreshed = await auth.attemptRefresh();

      expect(refreshed, isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.accessToken, isNull);
    });

    test('logout revokes server-side then clears local state', () async {
      final server = MockApiServer();
      final auth = AuthState(httpClient: server.client);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      await auth.logout();

      expect(server.logoutCalls, 1);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
      expect(auth.refreshToken, isNull);
    });

    test('logout still clears if the backend is unreachable', () async {
      final server = MockApiServer(behavior: Behavior(failLogout: true));
      final auth = AuthState(httpClient: server.client);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      await auth.logout();

      // Server-side revoke was attempted and failed, but local state cleared.
      expect(server.logoutCalls, 1);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
      expect(auth.refreshToken, isNull);
    });
  });
}
