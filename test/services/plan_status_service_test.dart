import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_grimoire_fresh/services/plan_status_service.dart';

void main() {
  group('PlanStatusSnapshot', () {
    test('fallback uses plan entitlements defaults', () {
      final snapshot = PlanStatusSnapshot.fallback('premium');
      expect(snapshot.tier, equals('premium'));
      expect(snapshot.limits['identifyPerDay'], equals(15));
      expect(snapshot.dailyUsage, isEmpty);
      expect(snapshot.flags, contains('stripe'));
    });

    test('fromJson coerces usage maps and timestamps', () {
      final snapshot = PlanStatusSnapshot.fromJson({
        'tier': 'Pro',
        'limits': {
          'identifyPerDay': 40,
        },
        'lifetime': false,
        'usage': {
          'daily': {
            'crystalIdentification': '5',
          },
          'lifetime': {
            'crystalIdentification': 120,
          },
          'lastResetDate': '2024-09-24',
          'updatedAt': '2024-09-24T05:00:00Z',
        },
        'flags': ['priority_support'],
      });

      expect(snapshot.tier, equals('pro'));
      expect(snapshot.usageFor('crystalIdentification'), equals(5));
      expect(snapshot.lifetimeUsageFor('crystalIdentification'), equals(120));
      expect(snapshot.updatedAt, isNotNull);
      expect(snapshot.updatedAt!.isUtc, isTrue);
    });
  });
}
