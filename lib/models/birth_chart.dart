import 'dart:math';

/// Astrological signs and their properties
enum ZodiacSign {
  aries('Aries', '♈', 'Fire', 'Cardinal'),
  taurus('Taurus', '♉', 'Earth', 'Fixed'),
  gemini('Gemini', '♊', 'Air', 'Mutable'),
  cancer('Cancer', '♋', 'Water', 'Cardinal'),
  leo('Leo', '♌', 'Fire', 'Fixed'),
  virgo('Virgo', '♍', 'Earth', 'Mutable'),
  libra('Libra', '♎', 'Air', 'Cardinal'),
  scorpio('Scorpio', '♏', 'Water', 'Fixed'),
  sagittarius('Sagittarius', '♐', 'Fire', 'Mutable'),
  capricorn('Capricorn', '♑', 'Earth', 'Cardinal'),
  aquarius('Aquarius', '♒', 'Air', 'Fixed'),
  pisces('Pisces', '♓', 'Water', 'Mutable');

  const ZodiacSign(this.name, this.symbol, this.element, this.modality);
  
  final String name;
  final String symbol;
  final String element;
  final String modality;
  
  /// Get compatible crystals for this sign
  List<String> get compatibleCrystals {
    switch (this) {
      case ZodiacSign.aries:
        return ['Carnelian', 'Red Jasper', 'Bloodstone', 'Diamond'];
      case ZodiacSign.taurus:
        return ['Rose Quartz', 'Emerald', 'Malachite', 'Aventurine'];
      case ZodiacSign.gemini:
        return ['Citrine', 'Agate', 'Clear Quartz', 'Tiger Eye'];
      case ZodiacSign.cancer:
        return ['Moonstone', 'Pearl', 'Selenite', 'Labradorite'];
      case ZodiacSign.leo:
        return ['Sunstone', 'Amber', 'Citrine', 'Pyrite'];
      case ZodiacSign.virgo:
        return ['Amazonite', 'Moss Agate', 'Fluorite', 'Sapphire'];
      case ZodiacSign.libra:
        return ['Rose Quartz', 'Opal', 'Lepidolite', 'Ametrine'];
      case ZodiacSign.scorpio:
        return ['Obsidian', 'Garnet', 'Malachite', 'Apache Tear'];
      case ZodiacSign.sagittarius:
        return ['Turquoise', 'Sodalite', 'Lapis Lazuli', 'Tanzanite'];
      case ZodiacSign.capricorn:
        return ['Garnet', 'Black Tourmaline', 'Hematite', 'Jet'];
      case ZodiacSign.aquarius:
        return ['Amethyst', 'Aquamarine', 'Fluorite', 'Celestite'];
      case ZodiacSign.pisces:
        return ['Amethyst', 'Aquamarine', 'Moonstone', 'Fluorite'];
    }
  }
}

/// Astrological houses
enum AstrologicalHouse {
  first('Self & Identity'),
  second('Values & Possessions'),
  third('Communication & Learning'),
  fourth('Home & Family'),
  fifth('Creativity & Romance'),
  sixth('Health & Service'),
  seventh('Partnerships'),
  eighth('Transformation & Shared Resources'),
  ninth('Philosophy & Higher Learning'),
  tenth('Career & Reputation'),
  eleventh('Friendships & Goals'),
  twelfth('Spirituality & Subconscious');

  const AstrologicalHouse(this.meaning);
  final String meaning;
}

/// Birth chart data
class BirthChart {
  final DateTime birthDate;
  final String birthTime; // HH:MM format
  final String birthLocation;
  final double latitude;
  final double longitude;
  final ZodiacSign sunSign;
  final ZodiacSign moonSign;
  final ZodiacSign ascendant;
  final Map<String, ZodiacSign> planetSigns;
  final Map<AstrologicalHouse, ZodiacSign> houses;
  final DateTime createdAt;

  BirthChart({
    required this.birthDate,
    required this.birthTime,
    required this.birthLocation,
    required this.latitude,
    required this.longitude,
    required this.sunSign,
    required this.moonSign,
    required this.ascendant,
    required this.planetSigns,
    required this.houses,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calculate birth chart from birth data (simplified)
  factory BirthChart.calculate({
    required DateTime birthDate,
    required String birthTime,
    required String birthLocation,
    required double latitude,
    required double longitude,
  }) {
    // Simplified calculation - in production would use Swiss Ephemeris
    final dayOfYear = birthDate.difference(DateTime(birthDate.year, 1, 1)).inDays;
    final sunSign = _calculateSunSign(dayOfYear);
    
    // Simplified moon and ascendant calculation
    final moonSign = _calculateMoonSign(birthDate, birthTime);
    final ascendant = _calculateAscendant(birthDate, birthTime, latitude);
    
    // Calculate planetary positions (simplified)
    final planetSigns = _calculatePlanetaryPositions(birthDate, birthTime);
    
    // Calculate house positions (simplified)
    final houses = _calculateHouses(ascendant);
    
    return BirthChart(
      birthDate: birthDate,
      birthTime: birthTime,
      birthLocation: birthLocation,
      latitude: latitude,
      longitude: longitude,
      sunSign: sunSign,
      moonSign: moonSign,
      ascendant: ascendant,
      planetSigns: planetSigns,
      houses: houses,
    );
  }

  /// Get personalized crystal recommendations based on chart
  List<String> getCrystalRecommendations() {
    final recommendations = <String>{};
    
    // Add crystals for sun sign
    recommendations.addAll(sunSign.compatibleCrystals);
    
    // Add crystals for moon sign
    recommendations.addAll(moonSign.compatibleCrystals);
    
    // Add crystals for ascendant
    recommendations.addAll(ascendant.compatibleCrystals);
    
    // Add crystals based on planetary positions
    for (final planetSign in planetSigns.values) {
      recommendations.addAll(planetSign.compatibleCrystals.take(2));
    }
    
    return recommendations.toList();
  }

  /// Get spiritual guidance context for AI
  Map<String, dynamic> getSpiritualContext() {
    return {
      'sunSign': {
        'sign': sunSign.name,
        'element': sunSign.element,
        'modality': sunSign.modality,
        'symbol': sunSign.symbol,
      },
      'moonSign': {
        'sign': moonSign.name,
        'element': moonSign.element,
        'modality': moonSign.modality,
      },
      'ascendant': {
        'sign': ascendant.name,
        'element': ascendant.element,
        'modality': ascendant.modality,
      },
      'dominantElements': _getDominantElements(),
      'recommendations': getCrystalRecommendations(),
      'currentTransits': _getCurrentTransits(),
    };
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'birthDate': birthDate.toIso8601String(),
      'birthTime': birthTime,
      'birthLocation': birthLocation,
      'latitude': latitude,
      'longitude': longitude,
      'sunSign': sunSign.name,
      'moonSign': moonSign.name,
      'ascendant': ascendant.name,
      'planetSigns': planetSigns.map((k, v) => MapEntry(k, v.name)),
      'houses': houses.map((k, v) => MapEntry(k.index.toString(), v.name)),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory BirthChart.fromJson(Map<String, dynamic> json) {
    return BirthChart(
      birthDate: DateTime.parse(json['birthDate']),
      birthTime: json['birthTime'],
      birthLocation: json['birthLocation'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      sunSign: ZodiacSign.values.firstWhere((s) => s.name == json['sunSign']),
      moonSign: ZodiacSign.values.firstWhere((s) => s.name == json['moonSign']),
      ascendant: ZodiacSign.values.firstWhere((s) => s.name == json['ascendant']),
      planetSigns: (json['planetSigns'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ZodiacSign.values.firstWhere((s) => s.name == v)),
      ),
      houses: (json['houses'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          AstrologicalHouse.values[int.parse(k)],
          ZodiacSign.values.firstWhere((s) => s.name == v),
        ),
      ),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Simplified calculations (in production would use proper ephemeris)
  static ZodiacSign _calculateSunSign(int dayOfYear) {
    // Approximate zodiac dates
    if (dayOfYear <= 19) return ZodiacSign.capricorn;
    if (dayOfYear <= 49) return ZodiacSign.aquarius;
    if (dayOfYear <= 80) return ZodiacSign.pisces;
    if (dayOfYear <= 110) return ZodiacSign.aries;
    if (dayOfYear <= 141) return ZodiacSign.taurus;
    if (dayOfYear <= 172) return ZodiacSign.gemini;
    if (dayOfYear <= 204) return ZodiacSign.cancer;
    if (dayOfYear <= 235) return ZodiacSign.leo;
    if (dayOfYear <= 266) return ZodiacSign.virgo;
    if (dayOfYear <= 296) return ZodiacSign.libra;
    if (dayOfYear <= 326) return ZodiacSign.scorpio;
    if (dayOfYear <= 356) return ZodiacSign.sagittarius;
    return ZodiacSign.capricorn;
  }

  static ZodiacSign _calculateMoonSign(DateTime date, String time) {
    // Simplified: moon moves ~13 degrees per day through signs
    final daysSinceNewMoon = date.difference(DateTime(2025, 1, 29)).inDays % 29;
    final signIndex = (daysSinceNewMoon * 12 / 29).floor() % 12;
    return ZodiacSign.values[signIndex];
  }

  static ZodiacSign _calculateAscendant(DateTime date, String time, double latitude) {
    // Simplified: based on time of day and latitude
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final timeDecimal = hour + (minute / 60.0);
    
    // Ascendant changes roughly every 2 hours
    final signIndex = ((timeDecimal / 2) + (latitude / 30)).floor() % 12;
    return ZodiacSign.values[signIndex];
  }

  static Map<String, ZodiacSign> _calculatePlanetaryPositions(DateTime date, String time) {
    // Simplified planetary positions
    final random = Random(date.millisecondsSinceEpoch);
    return {
      'Mercury': ZodiacSign.values[random.nextInt(12)],
      'Venus': ZodiacSign.values[random.nextInt(12)],
      'Mars': ZodiacSign.values[random.nextInt(12)],
      'Jupiter': ZodiacSign.values[random.nextInt(12)],
      'Saturn': ZodiacSign.values[random.nextInt(12)],
    };
  }

  static Map<AstrologicalHouse, ZodiacSign> _calculateHouses(ZodiacSign ascendant) {
    final houses = <AstrologicalHouse, ZodiacSign>{};
    final startIndex = ZodiacSign.values.indexOf(ascendant);
    
    for (int i = 0; i < 12; i++) {
      final signIndex = (startIndex + i) % 12;
      houses[AstrologicalHouse.values[i]] = ZodiacSign.values[signIndex];
    }
    
    return houses;
  }

  Map<String, int> _getDominantElements() {
    final elements = <String, int>{};
    
    // Count elements from sun, moon, ascendant
    _incrementElement(elements, sunSign.element);
    _incrementElement(elements, moonSign.element);
    _incrementElement(elements, ascendant.element);
    
    // Count elements from planets
    for (final planetSign in planetSigns.values) {
      _incrementElement(elements, planetSign.element);
    }
    
    return elements;
  }

  void _incrementElement(Map<String, int> elements, String element) {
    elements[element] = (elements[element] ?? 0) + 1;
  }

  List<String> _getCurrentTransits() {
    // Simplified current transits
    final now = DateTime.now();
    final currentSunSign = _calculateSunSign(now.difference(DateTime(now.year, 1, 1)).inDays);
    
    return [
      'Sun in ${currentSunSign.name}',
      'Mercury in communication focus',
      'Venus enhancing relationships',
    ];
  }
}