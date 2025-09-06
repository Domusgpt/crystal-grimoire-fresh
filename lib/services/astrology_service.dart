import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/birth_chart.dart';
import 'dart:math' as math;

class AstrologyService extends ChangeNotifier {
  static const List<Map<String, dynamic>> _zodiacSigns = [
    {'name': 'Aries', 'start': [3, 21], 'end': [4, 19], 'element': 'Fire'},
    {'name': 'Taurus', 'start': [4, 20], 'end': [5, 20], 'element': 'Earth'},
    {'name': 'Gemini', 'start': [5, 21], 'end': [6, 20], 'element': 'Air'},
    {'name': 'Cancer', 'start': [6, 21], 'end': [7, 22], 'element': 'Water'},
    {'name': 'Leo', 'start': [7, 23], 'end': [8, 22], 'element': 'Fire'},
    {'name': 'Virgo', 'start': [8, 23], 'end': [9, 22], 'element': 'Earth'},
    {'name': 'Libra', 'start': [9, 23], 'end': [10, 22], 'element': 'Air'},
    {'name': 'Scorpio', 'start': [10, 23], 'end': [11, 21], 'element': 'Water'},
    {'name': 'Sagittarius', 'start': [11, 22], 'end': [12, 21], 'element': 'Fire'},
    {'name': 'Capricorn', 'start': [12, 22], 'end': [1, 19], 'element': 'Earth'},
    {'name': 'Aquarius', 'start': [1, 20], 'end': [2, 18], 'element': 'Air'},
    {'name': 'Pisces', 'start': [2, 19], 'end': [3, 20], 'element': 'Water'},
  ];

  static const List<String> _moonPhaseNames = [
    'New Moon',
    'Waxing Crescent',
    'First Quarter',
    'Waxing Gibbous',
    'Full Moon',
    'Waning Gibbous',
    'Last Quarter',
    'Waning Crescent'
  ];

  // Known New Moon reference point (January 1, 2000)
  static final DateTime _newMoonReference = DateTime(2000, 1, 6, 18, 14);
  static const double _synodicMonth = 29.530588853; // Average synodic month in days
  static const String _baseUrl = 'https://json.freeastrologyapi.com';

  /// Calculate sun sign from birth date - LOCAL CALCULATION
  static String getSunSign(DateTime birthDate) {
    final month = birthDate.month;
    final day = birthDate.day;
    
    for (final sign in _zodiacSigns) {
      final start = sign['start'] as List<int>;
      final end = sign['end'] as List<int>;
      final startMonth = start[0];
      final startDay = start[1];
      final endMonth = end[0];
      final endDay = end[1];
      
      // Handle signs that cross year boundary (Capricorn)
      if (startMonth > endMonth) {
        if ((month == startMonth && day >= startDay) || 
            (month == endMonth && day <= endDay)) {
          return sign['name'] as String;
        }
      } else {
        if ((month == startMonth && day >= startDay) || 
            (month > startMonth && month < endMonth) ||
            (month == endMonth && day <= endDay)) {
          return sign['name'] as String;
        }
      }
    }
    
    return 'Aries'; // Fallback
  }

  /// Calculate current moon phase and age - LOCAL CALCULATION
  static Map<String, dynamic> getCurrentMoonPhase([DateTime? date]) {
    date ??= DateTime.now();
    
    // Calculate days since reference new moon
    final daysSinceReference = date.difference(_newMoonReference).inMilliseconds / (1000 * 60 * 60 * 24);
    
    // Calculate moon age (days into current lunar cycle)
    final moonAge = daysSinceReference % _synodicMonth;
    
    // Calculate illumination percentage
    final illumination = (1 - math.cos((moonAge / _synodicMonth) * 2 * math.pi)) / 2;
    
    // Determine phase name based on moon age
    String phaseName;
    int phaseIndex;
    
    if (moonAge < 1.84566) {
      phaseName = 'New Moon';
      phaseIndex = 0;
    } else if (moonAge < 5.53699) {
      phaseName = 'Waxing Crescent';
      phaseIndex = 1;
    } else if (moonAge < 9.22831) {
      phaseName = 'First Quarter';
      phaseIndex = 2;
    } else if (moonAge < 12.91963) {
      phaseName = 'Waxing Gibbous';
      phaseIndex = 3;
    } else if (moonAge < 16.61096) {
      phaseName = 'Full Moon';
      phaseIndex = 4;
    } else if (moonAge < 20.30228) {
      phaseName = 'Waning Gibbous';
      phaseIndex = 5;
    } else if (moonAge < 23.99361) {
      phaseName = 'Last Quarter';
      phaseIndex = 6;
    } else {
      phaseName = 'Waning Crescent';
      phaseIndex = 7;
    }
    
    return {
      'phase': phaseName,
      'phaseIndex': phaseIndex,
      'age': moonAge,
      'illumination': illumination,
      'isWaxing': moonAge < _synodicMonth / 2,
      'nextPhase': _getNextPhase(phaseIndex),
      'daysUntilNext': _getDaysUntilNextPhase(moonAge, phaseIndex),
    };
  }

  /// Get next moon phase info
  static Map<String, dynamic> _getNextPhase(int currentPhaseIndex) {
    final nextIndex = (currentPhaseIndex + 1) % _moonPhaseNames.length;
    return {
      'name': _moonPhaseNames[nextIndex],
      'index': nextIndex,
    };
  }

  /// Calculate days until next major phase
  static double _getDaysUntilNextPhase(double moonAge, int phaseIndex) {
    final phaseTargets = [0, 7.38, 14.77, 22.15]; // New, First Quarter, Full, Last Quarter
    final nextMajorPhase = ((phaseIndex ~/ 2) + 1) % 4;
    final targetAge = phaseTargets[nextMajorPhase];
    
    if (targetAge > moonAge) {
      return targetAge - moonAge;
    } else {
      return (_synodicMonth - moonAge) + targetAge;
    }
  }

  /// Get zodiac element for a sun sign
  static String getZodiacElement(String sunSign) {
    for (final sign in _zodiacSigns) {
      if (sign['name'] == sunSign) {
        return sign['element'] as String;
      }
    }
    return 'Fire'; // Fallback
  }

  /// Get compatible crystals for a sun sign
  static List<String> getSignCrystals(String sunSign) {
    final Map<String, List<String>> signCrystals = {
      'Aries': ['Carnelian', 'Red Jasper', 'Bloodstone', 'Diamond'],
      'Taurus': ['Rose Quartz', 'Emerald', 'Malachite', 'Green Aventurine'],
      'Gemini': ['Citrine', 'Agate', 'Tiger\'s Eye', 'Clear Quartz'],
      'Cancer': ['Moonstone', 'Pearl', 'Rose Quartz', 'Labradorite'],
      'Leo': ['Sunstone', 'Citrine', 'Pyrite', 'Amber'],
      'Virgo': ['Amazonite', 'Moss Agate', 'Carnelian', 'Peridot'],
      'Libra': ['Lapis Lazuli', 'Opal', 'Lepidolite', 'Green Tourmaline'],
      'Scorpio': ['Obsidian', 'Garnet', 'Malachite', 'Labradorite'],
      'Sagittarius': ['Turquoise', 'Lapis Lazuli', 'Sodalite', 'Amethyst'],
      'Capricorn': ['Garnet', 'Black Tourmaline', 'Fluorite', 'Hematite'],
      'Aquarius': ['Amethyst', 'Aquamarine', 'Fluorite', 'Labradorite'],
      'Pisces': ['Amethyst', 'Aquamarine', 'Moonstone', 'Fluorite'],
    };
    
    return signCrystals[sunSign] ?? ['Clear Quartz'];
  }

  /// Get moon phase crystals
  static List<String> getMoonPhaseCrystals(String moonPhase) {
    final Map<String, List<String>> phaseCrystals = {
      'New Moon': ['Black Tourmaline', 'Obsidian', 'Hematite', 'Smoky Quartz'],
      'Waxing Crescent': ['Clear Quartz', 'Citrine', 'Green Aventurine', 'Prehnite'],
      'First Quarter': ['Carnelian', 'Orange Calcite', 'Sunstone', 'Tiger\'s Eye'],
      'Waxing Gibbous': ['Rose Quartz', 'Green Jade', 'Amazonite', 'Aventurine'],
      'Full Moon': ['Moonstone', 'Selenite', 'Pearl', 'Clear Quartz'],
      'Waning Gibbous': ['Amethyst', 'Lepidolite', 'Blue Lace Agate', 'Celestite'],
      'Last Quarter': ['Black Obsidian', 'Apache Tear', 'Jet', 'Onyx'],
      'Waning Crescent': ['Smoky Quartz', 'Fluorite', 'Labradorite', 'Iolite'],
    };
    
    return phaseCrystals[moonPhase] ?? ['Clear Quartz'];
  }

  /// Generate astrological context for guidance - SPEC REQUIREMENT
  static Map<String, dynamic> getGuidanceContext({
    required DateTime birthDate,
    DateTime? currentDate,
  }) {
    currentDate ??= DateTime.now();
    final sunSign = getSunSign(birthDate);
    final moonPhase = getCurrentMoonPhase(currentDate);
    final element = getZodiacElement(sunSign);
    
    return {
      'sunSign': sunSign,
      'element': element,
      'moonPhase': moonPhase,
      'signCrystals': getSignCrystals(sunSign),
      'moonCrystals': getMoonPhaseCrystals(moonPhase['phase']),
      'seasonalContext': _getSeasonalContext(currentDate),
    };
  }

  /// Get seasonal context for deeper guidance
  static Map<String, String> _getSeasonalContext(DateTime date) {
    final month = date.month;
    
    if (month >= 3 && month <= 5) {
      return {'season': 'Spring', 'energy': 'Growth and new beginnings'};
    } else if (month >= 6 && month <= 8) {
      return {'season': 'Summer', 'energy': 'Manifestation and abundance'};
    } else if (month >= 9 && month <= 11) {
      return {'season': 'Autumn', 'energy': 'Release and transformation'};
    } else {
      return {'season': 'Winter', 'energy': 'Reflection and inner wisdom'};
    }
  }
  
  /// Calculate birth chart using Free Astrology API
  static Future<BirthChart> calculateBirthChart({
    required DateTime birthDate,
    required String birthTime,
    required String birthLocation,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Parse time
      final timeParts = birthTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Calculate timezone offset (simplified - in production use proper timezone library)
      final timezoneOffset = _estimateTimezone(longitude);
      
      // Prepare request data
      final requestData = {
        'day': birthDate.day,
        'month': birthDate.month,
        'year': birthDate.year,
        'hour': hour,
        'min': minute,
        'lat': latitude,
        'lon': longitude,
        'tzone': timezoneOffset,
      };
      
      // Get planetary positions
      final planetsResponse = await http.post(
        Uri.parse('$_baseUrl/planets'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      if (planetsResponse.statusCode != 200) {
        // Fallback to simplified calculation if API fails
        return _calculateSimplifiedChart(
          birthDate: birthDate,
          birthTime: birthTime,
          birthLocation: birthLocation,
          latitude: latitude,
          longitude: longitude,
        );
      }
      
      final planetsData = json.decode(planetsResponse.body);
      
      // Get house cusps
      final housesResponse = await http.post(
        Uri.parse('$_baseUrl/houses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          ...requestData,
          'house_system': 'placidus', // Most common house system
        }),
      );
      
      Map<String, dynamic>? housesData;
      if (housesResponse.statusCode == 200) {
        housesData = json.decode(housesResponse.body);
      }
      
      // Parse the API response into our BirthChart model
      return _parseBirthChart(
        birthDate: birthDate,
        birthTime: birthTime,
        birthLocation: birthLocation,
        latitude: latitude,
        longitude: longitude,
        planetsData: planetsData,
        housesData: housesData,
      );
      
    } catch (e) {
      // If API fails, use simplified calculation
      print('Astrology API error: $e');
      return _calculateSimplifiedChart(
        birthDate: birthDate,
        birthTime: birthTime,
        birthLocation: birthLocation,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }
  
  /// Parse API response into BirthChart model
  static BirthChart _parseBirthChart({
    required DateTime birthDate,
    required String birthTime,
    required String birthLocation,
    required double latitude,
    required double longitude,
    required Map<String, dynamic> planetsData,
    Map<String, dynamic>? housesData,
  }) {
    // Extract sun, moon, and ascendant from API data
    final sunData = _findPlanet(planetsData, 'Sun');
    final moonData = _findPlanet(planetsData, 'Moon');
    
    // Get zodiac signs from degrees
    final sunSign = _getZodiacFromDegree(sunData?['normDegree'] ?? 0);
    final moonSign = _getZodiacFromDegree(moonData?['normDegree'] ?? 0);
    
    // Calculate ascendant from houses data or estimate
    ZodiacSign ascendant;
    if (housesData != null && housesData['houses'] != null) {
      final firstHouse = housesData['houses']['1'] ?? housesData['houses']['first'];
      ascendant = _getZodiacFromDegree(firstHouse?['degree'] ?? 0);
    } else {
      // Simplified ascendant calculation
      ascendant = _calculateSimplifiedAscendant(birthDate, birthTime, latitude);
    }
    
    // Extract other planets
    final planetSigns = <String, ZodiacSign>{};
    final planetNames = ['Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];
    
    for (final planetName in planetNames) {
      final planetData = _findPlanet(planetsData, planetName);
      if (planetData != null) {
        planetSigns[planetName] = _getZodiacFromDegree(planetData['normDegree'] ?? 0);
      }
    }
    
    // If no planet data, use simplified positions
    if (planetSigns.isEmpty) {
      planetSigns.addAll(_calculateSimplifiedPlanets(birthDate, birthTime));
    }
    
    // Calculate houses
    final houses = _calculateHouses(ascendant, housesData);
    
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
  
  /// Find planet data in API response
  static Map<String, dynamic>? _findPlanet(Map<String, dynamic> data, String planetName) {
    if (data['planets'] is List) {
      final planets = data['planets'] as List;
      return planets.firstWhere(
        (p) => p['name'] == planetName,
        orElse: () => null,
      );
    } else if (data[planetName] != null) {
      return data[planetName];
    }
    return null;
  }
  
  /// Get zodiac sign from degree (0-360)
  static ZodiacSign _getZodiacFromDegree(double degree) {
    final signIndex = (degree / 30).floor() % 12;
    return ZodiacSign.values[signIndex];
  }
  
  /// Estimate timezone from longitude
  static double _estimateTimezone(double longitude) {
    // Rough estimate: 15 degrees = 1 hour
    return (longitude / 15).round().toDouble();
  }
  
  /// Calculate houses from ascendant
  static Map<AstrologicalHouse, ZodiacSign> _calculateHouses(
    ZodiacSign ascendant,
    Map<String, dynamic>? housesData,
  ) {
    final houses = <AstrologicalHouse, ZodiacSign>{};
    
    if (housesData != null && housesData['houses'] != null) {
      // Use actual house data if available
      for (int i = 0; i < 12; i++) {
        final houseData = housesData['houses'][(i + 1).toString()];
        if (houseData != null && houseData['degree'] != null) {
          houses[AstrologicalHouse.values[i]] = _getZodiacFromDegree(houseData['degree']);
        }
      }
    }
    
    // Fill any missing houses with equal house system
    if (houses.length < 12) {
      final startIndex = ZodiacSign.values.indexOf(ascendant);
      for (int i = 0; i < 12; i++) {
        if (!houses.containsKey(AstrologicalHouse.values[i])) {
          final signIndex = (startIndex + i) % 12;
          houses[AstrologicalHouse.values[i]] = ZodiacSign.values[signIndex];
        }
      }
    }
    
    return houses;
  }
  
  /// Simplified birth chart calculation (fallback)
  static BirthChart _calculateSimplifiedChart({
    required DateTime birthDate,
    required String birthTime,
    required String birthLocation,
    required double latitude,
    required double longitude,
  }) {
    // Use the existing simplified calculation from BirthChart.calculate
    return BirthChart.calculate(
      birthDate: birthDate,
      birthTime: birthTime,
      birthLocation: birthLocation,
      latitude: latitude,
      longitude: longitude,
    );
  }
  
  /// Simplified ascendant calculation
  static ZodiacSign _calculateSimplifiedAscendant(
    DateTime date,
    String time,
    double latitude,
  ) {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final timeDecimal = hour + (minute / 60.0);
    
    // Simplified: ascendant changes roughly every 2 hours
    final signIndex = ((timeDecimal / 2) + (latitude / 30)).floor() % 12;
    return ZodiacSign.values[signIndex];
  }
  
  /// Simplified planetary positions
  static Map<String, ZodiacSign> _calculateSimplifiedPlanets(
    DateTime date,
    String time,
  ) {
    // Very simplified - in reality planets move at different speeds
    final random = math.Random(date.millisecondsSinceEpoch);
    return {
      'Mercury': ZodiacSign.values[random.nextInt(12)],
      'Venus': ZodiacSign.values[random.nextInt(12)],
      'Mars': ZodiacSign.values[random.nextInt(12)],
      'Jupiter': ZodiacSign.values[random.nextInt(12)],
      'Saturn': ZodiacSign.values[random.nextInt(12)],
    };
  }
  
  /// Get coordinates from location name (simplified)
  static Future<Map<String, double>?> getCoordinatesFromLocation(String location) async {
    // In production, use a geocoding API like Google Maps or Nominatim
    // For now, return common city coordinates
    final commonCities = {
      'new york': {'lat': 40.7128, 'lon': -74.0060},
      'los angeles': {'lat': 34.0522, 'lon': -118.2437},
      'london': {'lat': 51.5074, 'lon': -0.1278},
      'paris': {'lat': 48.8566, 'lon': 2.3522},
      'tokyo': {'lat': 35.6762, 'lon': 139.6503},
      'sydney': {'lat': -33.8688, 'lon': 151.2093},
      'mumbai': {'lat': 19.0760, 'lon': 72.8777},
      'dubai': {'lat': 25.2048, 'lon': 55.2708},
    };
    
    final lowerLocation = location.toLowerCase();
    for (final city in commonCities.keys) {
      if (lowerLocation.contains(city)) {
        return commonCities[city];
      }
    }
    
    // Default to GMT/London if not found
    return {'lat': 51.5074, 'lon': -0.1278};
  }

  /// Get detailed moon phase information for a date range
  static List<Map<String, dynamic>> getMoonPhaseCalendar(DateTime start, int days) {
    final List<Map<String, dynamic>> phases = [];
    
    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final phaseInfo = getCurrentMoonPhase(date);
      phases.add({
        'date': date,
        ...phaseInfo,
      });
    }
    
    return phases;
  }
}