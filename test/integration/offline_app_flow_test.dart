import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crystal_grimoire_fresh/config/plan_entitlements.dart';
import 'package:crystal_grimoire_fresh/models/crystal.dart';
import 'package:crystal_grimoire_fresh/services/app_state.dart';
import 'package:crystal_grimoire_fresh/services/usage_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline app flow integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AppState can initialize, add crystals, and record identifications offline', () async {
      final appState = AppState();
      await appState.initialize();

      expect(appState.subscriptionTier, 'free');
      expect(appState.collectionCount, 0);
      expect(appState.recentIdentifications, isEmpty);

      final crystal = Crystal(
        id: 'clear-quartz',
        name: 'Clear Quartz',
        scientificName: 'SiO2',
        description: 'Amplifies the intention of every ritual.',
        metaphysicalProperties: const ['Amplification'],
        healingProperties: const ['Energising'],
        chakras: const ['Crown'],
        elements: const ['Air'],
        properties: const {},
        colorDescription: 'Clear',
        hardness: '7',
        formation: 'Hexagonal',
        careInstructions: 'Cleanse in moonlight once per week.',
        type: 'Quartz',
        color: 'Transparent',
        imageUrl: 'https://example.com/images/clear-quartz.png',
        planetaryRulers: const ['Sun'],
        zodiacSigns: const ['All'],
        crystalSystem: 'Trigonal',
        formations: const ['Points'],
        chargingMethods: const ['Moonlight'],
        cleansingMethods: const ['Sound'],
        bestCombinations: const ['Amethyst'],
        recommendedIntentions: const ['Clarity'],
        vibrationFrequency: 'High',
        energyType: 'Amplifying',
        bestTimeToUse: 'Morning',
        effectDuration: 'Hours',
        birthChartAlignment: const {},
        keywords: const ['Clarity', 'Amplify'],
        imageUrls: const [],
      );

      await appState.addCrystal(crystal);
      expect(appState.collectionCount, 1);

      final identification = CrystalIdentification(
        sessionId: 'session-1',
        fullResponse: '{"crystal":"Clear Quartz"}',
        crystal: crystal,
        confidence: 0.92,
        needsMoreInfo: false,
        suggestedAngles: const ['Top'],
        observedFeatures: const ['Glass-like clarity'],
        mysticalMessage: 'Your path clears when your intention is precise.',
        timestamp: DateTime.now(),
      );

      appState.addRecentIdentification(identification);
      expect(appState.recentIdentifications, isNotEmpty);
      expect(appState.recentIdentifications.first.sessionId, 'session-1');
    });

    test('UsageTracker stores usage counters and respects subscription upgrades', () async {
      expect(await UsageTracker.canIdentify(), isTrue);

      await UsageTracker.recordUsage();
      await UsageTracker.recordUsage();

      final stats = await UsageTracker.getUsageStats();
      expect(stats.monthlyUsage, 2);
      expect(stats.subscriptionTier, 'free');

      await UsageTracker.updateSubscriptionTier('pro');
      final upgraded = await UsageTracker.getUsageStats();
      expect(upgraded.subscriptionTier, 'pro');
      expect(upgraded.monthlyLimit, -1); // Unlimited once upgraded
    });

    test('Plan entitlements expose new quota fields for premium tiers', () {
      final proLimits = PlanEntitlements.effectiveLimits('pro');
      expect(proLimits['dreamAnalysesPerDay'], 20);
      expect(proLimits['recommendationsPerDay'], 25);
      expect(proLimits['moonRitualsPerDay'], 20);
    });
  });
}
