class PlanDetails {
  final String tier;
  final Map<String, int> effectiveLimits;
  final List<String> flags;
  final bool lifetime;

  const PlanDetails({
    required this.tier,
    required this.effectiveLimits,
    this.flags = const [],
    this.lifetime = false,
  });

  Map<String, int> get limits => Map.unmodifiable(effectiveLimits);
  List<String> get planFlags => List.unmodifiable(flags);
}

class PlanEntitlements {
  static const Map<String, PlanDetails> _plans = {
    'free': PlanDetails(
      tier: 'free',
      effectiveLimits: {
        'identifyPerDay': 3,
        'guidancePerDay': 1,
        'dreamAnalysesPerDay': 1,
        'recommendationsPerDay': 2,
        'moonRitualsPerDay': 1,
        'journalMax': 50,
        'collectionMax': 50,
      },
      flags: ['free'],
    ),
    'premium': PlanDetails(
      tier: 'premium',
      effectiveLimits: {
        'identifyPerDay': 15,
        'guidancePerDay': 5,
        'dreamAnalysesPerDay': 5,
        'recommendationsPerDay': 8,
        'moonRitualsPerDay': 5,
        'journalMax': 200,
        'collectionMax': 250,
      },
      flags: ['priority_support', 'stripe'],
    ),
    'pro': PlanDetails(
      tier: 'pro',
      effectiveLimits: {
        'identifyPerDay': 40,
        'guidancePerDay': 15,
        'dreamAnalysesPerDay': 20,
        'recommendationsPerDay': 25,
        'moonRitualsPerDay': 20,
        'journalMax': 500,
        'collectionMax': 1000,
      },
      flags: ['priority_support', 'advanced_models', 'stripe'],
    ),
    'founders': PlanDetails(
      tier: 'founders',
      effectiveLimits: {
        'identifyPerDay': 999,
        'guidancePerDay': 200,
        'dreamAnalysesPerDay': 200,
        'recommendationsPerDay': 300,
        'moonRitualsPerDay': 200,
        'journalMax': 2000,
        'collectionMax': 2000,
      },
      flags: ['lifetime', 'founder', 'priority_support', 'stripe'],
      lifetime: true,
    ),
  };

  static const Map<String, String> _aliases = {
    'explorer': 'free',
    'emissary': 'premium',
    'ascended': 'pro',
    'esper': 'founders',
  };

  static PlanDetails resolve(String? tier) {
    final normalized = (tier ?? 'free').trim().toLowerCase();
    final key = _plans.containsKey(normalized)
        ? normalized
        : _aliases[normalized] ?? 'free';
    return _plans[key]!;
  }

  static Map<String, int> effectiveLimits(String? tier) {
    return Map<String, int>.from(resolve(tier).effectiveLimits);
  }

  static List<String> flags(String? tier) {
    return List<String>.from(resolve(tier).flags);
  }

  static bool isLifetime(String? tier) {
    return resolve(tier).lifetime;
  }
}
