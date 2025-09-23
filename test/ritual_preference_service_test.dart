import 'package:flutter_test/flutter_test.dart';
import 'package:crystal_grimoire_fresh/services/ritual_preference_service.dart';

void main() {
  test('sanitizeMoonMetadata keeps supported fields only', () {
    final sanitized = RitualPreferenceService.sanitizeMoonMetadata({
      'phase': 'Full Moon',
      'emoji': '🌕',
      'illumination': 0.97,
      'timestamp': '2025-03-25T02:30:00Z',
      'focus': 'release',
      'nextPhases': [
        {'phase': 'Waning Gibbous', 'date': '2025-03-26'},
        {'phase': 'Last Quarter', 'date': '2025-03-30'},
      ],
      'extra': 'ignored',
      'meta': {'nested': true},
    });

    expect(sanitized, isNotNull);
    expect(sanitized!['phase'], 'Full Moon');
    expect(sanitized['emoji'], '🌕');
    expect(sanitized['illumination'], 0.97);
    expect(sanitized.containsKey('extra'), isFalse);
    expect(sanitized['nextPhases'], isA<List>());
    expect((sanitized['nextPhases'] as List).length, 2);
  });
}
