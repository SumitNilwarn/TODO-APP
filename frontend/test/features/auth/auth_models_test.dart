import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/auth/domain/auth_models.dart';

void main() {
  group('TokenResponse', () {
    test('parses the wire payload with defaults', () {
      final tokens = TokenResponse.fromJson(const {
        'accessToken': 'a',
        'refreshToken': 'r',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
      });

      expect(tokens.accessToken, 'a');
      expect(tokens.refreshToken, 'r');
      expect(tokens.tokenType, 'Bearer');
      expect(tokens.expiresIn, 3600);
    });

    test('defaults the token type when omitted', () {
      final tokens = TokenResponse.fromJson(const {
        'accessToken': 'a',
        'refreshToken': 'r',
      });
      expect(tokens.tokenType, 'Bearer');
      expect(tokens.expiresIn, isNull);
    });

    test('round-trips through toJson', () {
      const tokens = TokenResponse(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'Bearer',
        expiresIn: 30,
      );
      final reparsed = TokenResponse.fromJson(tokens.toJson());
      expect(reparsed, tokens);
    });

    test('equality is per token pair', () {
      const a = TokenResponse(accessToken: 'a', refreshToken: 'r');
      const b = TokenResponse(accessToken: 'a', refreshToken: 'r');
      const c = TokenResponse(accessToken: 'a', refreshToken: 'other');
      expect(a, b);
      expect(a == c, isFalse);
    });
  });

  group('CurrentUser', () {
    test('parses identity fields', () {
      final user = CurrentUser.fromJson(const {
        'userId': 'u1',
        'username': 'ada',
        'email': 'ada@example.com',
      });
      expect(user.userId, 'u1');
      expect(user.username, 'ada');
      expect(user.email, 'ada@example.com');
    });

    test('round-trips through toJson', () {
      const user = CurrentUser(
        userId: 'u1',
        username: 'ada',
        email: 'ada@example.com',
      );
      expect(CurrentUser.fromJson(user.toJson()), user);
    });
  });

  group('RegisterResult', () {
    test('parses returned identity', () {
      final result = RegisterResult.fromJson(const {
        'userId': 'u1',
        'username': 'ada',
      });
      expect(result.userId, 'u1');
      expect(result.username, 'ada');
    });
  });
}
