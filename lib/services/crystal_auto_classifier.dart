import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/crystal_collection.dart';
import '../models/crystal.dart';
import 'environment_config.dart';
import 'firebase_service.dart';
import 'unified_data_service.dart';

/// Crystal Auto-Classifier Service for automatic metaphysical property identification
/// Uses advanced AI to identify crystals and auto-populate ALL spiritual properties
class CrystalAutoClassifier extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final UnifiedDataService _unifiedDataService;
  final EnvironmentConfig _config;
  
  CrystalAutoClassifier({
    required FirebaseService firebaseService,
    required UnifiedDataService unifiedDataService,
    EnvironmentConfig? config,
  }) : _firebaseService = firebaseService,
       _unifiedDataService = unifiedDataService,
       _config = config ?? EnvironmentConfig();
  
  /// Auto-classify crystal from image and return complete metaphysical data
  Future<CrystalClassificationResult> classifyCrystal({
    required String imagePath,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('Auto-classification requires premium subscription');
    }
    
    try {
      // Get spiritual context for personalization
      final spiritualContext = _unifiedDataService.getSpiritualContext();
      
      // Call enhanced AI for classification
      final result = await _callClassificationAPI(imagePath, spiritualContext);
      
      // Parse and validate JSON response
      final classificationData = jsonDecode(result['response']);
      
      // Create Crystal object from classification
      final crystal = _createCrystalFromClassification(classificationData);
      
      return CrystalClassificationResult(
        crystal: crystal,
        confidence: classificationData['identification']['confidence'].toDouble(),
        rawClassification: classificationData,
      );
      
    } catch (e) {
      debugPrint('Crystal classification failed: $e');
      throw Exception('Failed to classify crystal: $e');
    }
  }
  
  /// Call Firebase Cloud Function for crystal classification
  Future<Map<String, dynamic>> _callClassificationAPI(String imagePath, Map<String, dynamic> context) async {
    final imageData = await _encodeImage(imagePath);
    
    final requestData = {
      'image_data': imageData,
      'user_context': context,
      'classification_type': 'full_metaphysical',
    };
    
    return await _firebaseService.callEnhancedAPI('crystalAutoClassifier', requestData);
  }
  
  /// Create Crystal object from AI classification JSON
  Crystal _createCrystalFromClassification(Map<String, dynamic> data) {
    final identification = data['identification'];
    final physical = data['physical_properties'];
    final metaphysical = data['metaphysical_properties'];
    final usage = data['usage_recommendations'];
    final astro = data['astrological_alignment'];
    final energy = data['energy_profile'];
    
    return Crystal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: identification['name'],
      type: identification['variety'],
      description: _generateDescription(data),
      properties: List<String>.from(metaphysical['healing_properties']),
      chakras: List<String>.from(metaphysical['primary_chakras']),
      color: physical['color'],
      imageUrl: '', // Will be set after upload
      
      // Extended metaphysical properties
      scientificName: identification['scientific_name'],
      colorDescription: physical['color_variations'].join(', '),
      metaphysicalProperties: List<String>.from(metaphysical['spiritual_properties']),
      healing: List<String>.from(metaphysical['healing_properties']),
      hardness: physical['hardness'].toDouble(),
      keywords: List<String>.from(metaphysical['emotional_properties']),
      
      // Auto-classified properties
      elements: List<String>.from(metaphysical['elements']),
      planetaryRulers: List<String>.from(metaphysical['planetary_rulers']),
      zodiacSigns: List<String>.from(metaphysical['zodiac_signs']),
      crystalSystem: physical['crystal_system'],
      formations: List<String>.from(physical['formations']),
      
      // Usage data
      chargingMethods: List<String>.from(usage['charging_methods']),
      cleansingMethods: List<String>.from(usage['cleansing_methods']),
      bestCombinations: List<String>.from(usage['combinations']),
      recommendedIntentions: List<String>.from(usage['intentions']),
      
      // Energy profile
      vibrationFrequency: energy['vibration_frequency'],
      energyType: energy['energy_type'],
      bestTimeToUse: energy['best_time_to_use'],
      effectDuration: energy['duration_of_effects'],
      
      // Astrological data
      birthChartAlignment: astro,
    );
  }
  
  /// Generate comprehensive description from classification data
  String _generateDescription(Map<String, dynamic> data) {
    final identification = data['identification'];
    final physical = data['physical_properties'];
    final metaphysical = data['metaphysical_properties'];
    
    return '''
${identification['name']} is a ${physical['color']} ${identification['variety']} crystal with ${physical['hardness']} hardness. 
This powerful stone resonates with the ${metaphysical['primary_chakras'].join(' and ')} chakra(s) and aligns with ${metaphysical['elements'].join(', ')} energy.

Known for its ${metaphysical['healing_properties'].take(3).join(', ')} properties, it's particularly effective for ${metaphysical['emotional_properties'].take(2).join(' and ')}.

Scientific composition: ${identification['scientific_name']}
Crystal system: ${physical['crystal_system']}
Formation: ${physical['formations'].join(', ')}
''';
  }
  
  /// Encode image for API transmission
  Future<String> _encodeImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to encode image: $e');
    }
  }
  
  /// Get the system prompt for the AI classifier
  static String getClassificationPrompt(Map<String, dynamic> userContext) {
    final birthChart = userContext['birth_chart'] ?? {};
    final sunSign = birthChart['sun_sign'] ?? 'Unknown';
    final moonSign = birthChart['moon_sign'] ?? 'Unknown';
    
    return '''
You are an expert crystal identification system. Analyze this crystal image and return ONLY a valid JSON object with complete metaphysical classification data.

RESPONSE FORMAT (JSON ONLY):
{
  "identification": {
    "name": "exact crystal name",
    "variety": "specific variety or type",
    "scientific_name": "chemical composition",
    "confidence": 95,
    "alternative_names": ["common alternate names"]
  },
  "physical_properties": {
    "color": "primary color",
    "color_variations": ["all color variations"],
    "hardness": 7.0,
    "crystal_system": "cubic/hexagonal/triclinic/tetragonal/orthorhombic/monoclinic",
    "luster": "vitreous/silky/metallic/resinous/pearly",
    "transparency": "transparent/translucent/opaque",
    "formations": ["cluster", "point", "tumbled", "raw", "geode", "druzy"]
  },
  "metaphysical_properties": {
    "primary_chakras": ["Root", "Sacral", "Solar Plexus", "Heart", "Throat", "Third Eye", "Crown"],
    "secondary_chakras": ["additional chakras if any"],
    "elements": ["Earth", "Water", "Fire", "Air", "Spirit"],
    "planetary_rulers": ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"],
    "zodiac_signs": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"],
    "healing_properties": ["physical healing properties"],
    "emotional_properties": ["emotional benefits"],
    "spiritual_properties": ["spiritual benefits"],
    "magical_properties": ["manifestation", "protection", "divination", "etc"]
  },
  "usage_recommendations": {
    "meditation": "specific meditation instructions",
    "placement": "where to place for optimal energy",
    "charging_methods": ["full moon", "new moon", "sunlight", "earth burial", "sound bowl"],
    "cleansing_methods": ["running water", "salt water", "smoke", "sound", "moonlight"],
    "combinations": ["crystals that amplify this stone's energy"],
    "intentions": ["specific intentions this crystal supports"]
  },
  "astrological_alignment": {
    "sun_sign_compatibility": "how it works with ${sunSign}",
    "moon_sign_compatibility": "how it works with ${moonSign}",
    "current_transit_benefits": "benefits for current planetary transits",
    "birth_chart_enhancement": "how it enhances their astrological profile"
  },
  "energy_profile": {
    "vibration_frequency": "high/medium/low",
    "energy_type": "calming/energizing/balancing/grounding/uplifting",
    "best_time_to_use": "dawn/noon/dusk/midnight/full moon/new moon",
    "duration_of_effects": "immediate/hours/days/ongoing/cumulative"
  }
}

CRITICAL REQUIREMENTS:
1. Return ONLY valid JSON - no additional text before or after
2. Be 95%+ accurate in crystal identification
3. Include ALL metaphysical properties automatically
4. Classify chakras, zodiac signs, elements precisely based on traditional crystal healing knowledge
5. Provide specific, actionable usage instructions
6. Consider their birth chart (Sun: ${sunSign}, Moon: ${moonSign}) for personalized alignment
7. Include both primary and secondary chakra associations
8. List all relevant planetary rulers and zodiac correspondences
9. Specify exact charging and cleansing methods
10. Recommend crystals that work synergistically

Analyze the crystal image and return the complete JSON classification with 100% accuracy.
''';
  }
}

/// Result of crystal auto-classification
class CrystalClassificationResult {
  final Crystal crystal;
  final double confidence;
  final Map<String, dynamic> rawClassification;
  
  CrystalClassificationResult({
    required this.crystal,
    required this.confidence,
    required this.rawClassification,
  });
  
  bool get isHighConfidence => confidence >= 90.0;
  bool get isReliable => confidence >= 80.0;
}