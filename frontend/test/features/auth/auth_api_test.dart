import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/api/api_client.dart';
import 'package:todo_app/data/api/api_exception.dart';
import 'package:todo_app/features/auth/data/auth_api.dart';

import '../../support/mock_api.dart';

const _base = 'http://test.local';

void main() {
  AuthApi api(MockApiServer server) =>
      AuthApi(ApiClient(baseUrl: _base, httpClient: server.client));

  group('AuthApi', () {
    test('login returns the parsed token pair', () async {
      final server = MockApiServer();
      final tokens = await api(server)
          .login(username: 'ada', password: 'password123');
      expect(tokens.accessToken, mockTokens['accessToken']);
      expect(tokens.refreshToken, mockTokens['refreshToken']);
    });

    test('register returns the parsed identity', () async {
      final server = MockApiServer();
      final result = await api(server).register(
        username: 'ada',
        email: 'ada@example.com',
        password: 'password123',
      );
      expect(result.userId, 'user-1');
      expect(result.username, 'ada');
    });

    test('refresh returns the rotated token pair', () async {
      final server = MockApiServer();
      final tokens = await api(server).refresh('refresh-token-1');
      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.refreshToken, isNotEmpty);
      expect(server.refreshCalls, 1);
    });

    test('me returns the parsed current user', () async {
      final server = MockApiServer();
      final user = await api(server).me();
      expect(user.userId, 'user-1');
      expect(user.username, 'ada');
    });

    test('logout issues the request idempotently', () async {
      final server = MockApiServer();
      await api(server).logout('refresh-token-1');
      expect(server.logoutCalls, 1);
    });

    test('login throws ApiException on a failed login envelope', () async {
      final server = MockApiServer(behavior: Behavior(failLogin: true));
      await expectLater(
        api(server).login(username: 'ada', password: 'bad'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'AUTHENTICATION_FAILED')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('register throws ApiException on a conflict envelope', () async {
      final server = MockApiServer(behavior: Behavior(failRegister: true));
      await expectLater(
        api(server).register(
          username: 'taken',
          email: 'taken@example.com',
          password: 'password123',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'USERNAME_ALREADY_TAKEN')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });
  });
}
