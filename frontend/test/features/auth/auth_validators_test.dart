import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/auth/domain/auth_validators.dart';

void main() {
  group('username', () {
    test('accepts valid usernames', () {
      expect(validateUsername('ada'), isNull);
      expect(validateUsername('ada_lovelace'), isNull);
      expect(validateUsername('a-b.c_1'), isNull);
      expect(validateUsername('A' * 50), isNull);
    });

    test('rejects empty and short values', () {
      expect(validateUsername(''), isNotNull);
      expect(validateUsername('  '), isNotNull);
      expect(validateUsername('ab'), isNotNull);
    });

    test('rejects invalid characters', () {
      expect(validateUsername('ada lovelace'), isNotNull);
      expect(validateUsername('ad@a'), isNotNull);
      expect(validateUsername('ada!'), isNotNull);
    });

    test('rejects overlong usernames', () {
      expect(validateUsername('a' * 51), isNotNull);
    });
  });

  group('email', () {
    test('accepts valid emails', () {
      expect(validateEmail('ada@example.com'), isNull);
      expect(validateEmail('a.b+c@sub.example.co'), isNull);
    });

    test('rejects malformed emails', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('ada@'), isNotNull);
      expect(validateEmail('@example.com'), isNotNull);
      expect(validateEmail('ada@example'), isNotNull);
      expect(validateEmail('ada example.com'), isNotNull);
    });

    test('rejects overlong emails', () {
      expect(validateEmail('${'a' * 250}@example.com'), isNotNull);
    });
  });

  group('password', () {
    test('accepts strong-enough passwords', () {
      expect(validatePassword('password123'), isNull);
      expect(validatePassword('complex-password-2'), isNull);
    });

    test('mirrors the length bounds', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('abc123'), isNotNull); // < 10
      expect(validatePassword('a' * 101), isNotNull); // > 100
    });

    test('requires a letter and a digit', () {
      expect(validatePassword('passwordone'), isNotNull); // no digit
      expect(validatePassword('1234567890'), isNotNull); // no letter
      expect(validatePassword('password123'), isNull);
    });

    test('confirmation must match and be non-empty', () {
      expect(validatePasswordConfirmation('', 'password1'), isNotNull);
      expect(validatePasswordConfirmation('password2', 'password1'), isNotNull);
      expect(validatePasswordConfirmation('password1', 'password1'), isNull);
    });
  });
}
