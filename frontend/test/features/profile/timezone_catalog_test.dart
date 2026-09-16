import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/profile/domain/timezone_catalog.dart';

void main() {
  group('Timezone catalog', () {
    test('loads a non-empty candidate list', () async {
      final candidates = await loadTimezoneCandidates();
      expect(candidates, isNotEmpty);
      expect(candidates, containsAll(['UTC', 'Europe/London', 'Asia/Tokyo']));
    });

    test('every curated candidate is IANA-shaped', () {
      for (final zone in curatedTimezoneCatalog) {
        expect(
          looksLikeIanaTimezone(zone),
          isTrue,
          reason: '$zone should be IANA-shaped',
        );
      }
    });
  });

  group('looksLikeIanaTimezone', () {
    test('accepts valid ids', () {
      expect(looksLikeIanaTimezone('America/New_York'), isTrue);
      expect(looksLikeIanaTimezone('Etc/UTC'), isTrue);
      expect(looksLikeIanaTimezone('UTC'), isTrue);
      expect(looksLikeIanaTimezone('America/Argentina/Buenos_Aires'), isTrue);
    });

    test('rejects malformed values', () {
      expect(looksLikeIanaTimezone(''), isFalse);
      expect(looksLikeIanaTimezone('  '), isFalse);
      expect(looksLikeIanaTimezone('New York'), isFalse);
      expect(looksLikeIanaTimezone('A' * 65), isFalse);
      expect(looksLikeIanaTimezone('UTC UTC'), isFalse);
    });
  });
}
