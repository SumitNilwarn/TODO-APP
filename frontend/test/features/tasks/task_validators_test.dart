import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/tasks/domain/task_validators.dart';

void main() {
  group('title', () {
    test('mirrors the documented length constants', () {
      expect(kTaskTitleMaxLength, 200);
      expect(kTaskDescriptionMaxLength, 2000);
      expect(kTaskSearchMaxLength, 200);
    });

    test('accepts a non-blank title up to 200 characters', () {
      expect(validateTaskTitle('Plan the launch'), isNull);
      expect(validateTaskTitle('A' * 200), isNull);
      expect(validateTaskTitle('  Trimmed  '), isNull);
    });

    test('rejects null and blank titles', () {
      expect(validateTaskTitle(null), isNotNull);
      expect(validateTaskTitle(''), isNotNull);
      expect(validateTaskTitle('   '), isNotNull);
    });

    test('rejects titles longer than 200 characters', () {
      final error = validateTaskTitle('A' * 201);
      expect(error, isNotNull);
      expect(error, 'Title must be at most 200 characters long.');
    });
  });

  group('description', () {
    test('accepts null, empty and blank descriptions', () {
      expect(validateTaskDescription(null), isNull);
      expect(validateTaskDescription(''), isNull);
      expect(validateTaskDescription('   '), isNull);
    });

    test('accepts a description up to 2000 characters', () {
      expect(validateTaskDescription('B' * 2000), isNull);
    });

    test('rejects descriptions longer than 2000 characters', () {
      final error = validateTaskDescription('B' * 2001);
      expect(error, isNotNull);
      expect(error, 'Description must be at most 2000 characters long.');
    });
  });
}
