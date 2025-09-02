import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/birth_chart.dart';
import 'dart:math' as math;

class AstrologyService {
  static const String _baseUrl = 'https://json.freeastrologyapi.com';
  
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
}