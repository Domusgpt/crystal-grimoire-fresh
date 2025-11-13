import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/crystal_model.dart';

class CrystalService extends ChangeNotifier {
  FirebaseFunctions? _functions;
  FirebaseFunctions get functions => _functions ??= FirebaseFunctions.instance;
  
  bool _isIdentifying = false;
  bool get isIdentifying => _isIdentifying;
  
  Crystal? _lastIdentifiedCrystal;
  Crystal? get lastIdentifiedCrystal => _lastIdentifiedCrystal;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // Identify crystal from image
  Future<Map<String, dynamic>?> identifyCrystal(Uint8List imageBytes) async {
    try {
      _isIdentifying = true;
      _errorMessage = null;
      notifyListeners();
      
      // Convert image to base64
      final base64Image = base64Encode(imageBytes);
      
      // Call Cloud Function
      final callable = functions.httpsCallable('identifyCrystal');
      final result = await callable.call({
        'imageData': base64Image,
        'includeMetaphysical': true,
        'includeHealing': true,
        'includeCare': true,
      });
      
      final data = result.data as Map<String, dynamic>;
      final identification = (data['identification'] as Map<String, dynamic>?) ?? {};
      final structured = (data['structured_data'] as Map<String, dynamic>?) ?? {};
      final structuredMetaphysical =
          (structured['metaphysical_properties'] as Map<String, dynamic>?) ?? {};
      final metaphysical =
          (data['metaphysical_properties'] as Map<String, dynamic>?) ?? structuredMetaphysical;
      final geological = (data['geological_data'] as Map<String, dynamic>?) ??
          (structured['geological_data'] as Map<String, dynamic>?) ?? {};
      final colors = List<String>.from(
        (data['colors'] as List?) ??
            (structured['colors'] as List?) ??
            const [],
      );

      final elementValue = structuredMetaphysical['element'] ?? metaphysical['element'];

      final metaphysicalWithElements = {
        ...metaphysical,
        if (structuredMetaphysical.isNotEmpty) ...structuredMetaphysical,
        if (elementValue != null) 'element': elementValue,
        'elements': _listifyElements(
          structuredMetaphysical['elements'] ?? metaphysical['elements'],
          elementValue,
        ),
      };

      final analysisDate = data['analysis_date'] ?? structured['analysis_date'];

      final physicalProperties = {
        ...((data['physical_properties'] as Map<String, dynamic>?) ?? {}),
        if (geological['mohs_hardness'] != null)
          'hardness': geological['mohs_hardness'],
        if (geological['chemical_formula'] != null)
          'chemicalFormula': geological['chemical_formula'],
        if (analysisDate != null) 'analysisDate': analysisDate,
        'colorRange': colors,
      };

      // Create Crystal object from result
      _lastIdentifiedCrystal = Crystal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: identification['name'] ??
            structured['crystal_type'] ??
            'Unknown Crystal',
        scientificName: geological['chemical_formula']?.toString() ?? '',
        variety: identification['variety']?.toString() ?? '',
        imageUrl: data['imageUrl']?.toString() ?? '',
        metaphysicalProperties: metaphysicalWithElements,
        physicalProperties: physicalProperties,
        careInstructions:
            (data['care_instructions'] as Map<String, dynamic>?) ?? const {},
        healingProperties: List<String>.from(
          metaphysicalWithElements['healing_properties'] ?? const [],
        ),
        chakras: List<String>.from(
          metaphysicalWithElements['primary_chakras'] ?? const [],
        ),
        zodiacSigns: List<String>.from(
          metaphysicalWithElements['zodiac_signs'] ?? const [],
        ),
        elements: List<String>.from(
          metaphysicalWithElements['elements'] ?? const [],
        ),
        description:
            data['description']?.toString() ?? data['report']?.toString() ?? '',
      );
      
      _isIdentifying = false;
      notifyListeners();
      
      return data;
    } catch (e) {
      _errorMessage = 'Failed to identify crystal: ${e.toString()}';
      _isIdentifying = false;
      notifyListeners();
      return null;
    }
  }
  
  // Get personalized crystal guidance
  Future<String?> getCrystalGuidance({
    required String crystalName,
    required Map<String, dynamic> userProfile,
    String? intention,
  }) async {
    try {
      final callable = functions.httpsCallable('getCrystalGuidance');
      final result = await callable.call({
        'crystalName': crystalName,
        'userProfile': userProfile,
        'intention': intention,
      });
      
      return result.data['guidance'] as String?;
    } catch (e) {
      debugPrint('Error getting crystal guidance: $e');
      return null;
    }
  }
  
  // Get crystal recommendations based on user needs
  Future<List<Crystal>?> getRecommendations({
    required String need,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      final callable = functions.httpsCallable('getCrystalRecommendations');
      final result = await callable.call({
        'need': need,
        'userProfile': userProfile,
      });
      
      final recommendations = result.data['recommendations'] as List<dynamic>;
      
      return recommendations.map((data) => Crystal(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        scientificName: data['scientificName'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        metaphysicalProperties: data['metaphysicalProperties'] ?? {},
        physicalProperties: data['physicalProperties'] ?? {},
        careInstructions: data['careInstructions'] ?? {},
        healingProperties: List<String>.from(data['healingProperties'] ?? []),
        chakras: List<String>.from(data['chakras'] ?? []),
        zodiacSigns: List<String>.from(data['zodiacSigns'] ?? []),
        elements: List<String>.from(data['elements'] ?? []),
        description: data['description'] ?? '',
      )).toList();
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      return null;
    }
  }
  
  // Generate healing layout with crystals
  Future<Map<String, dynamic>?> generateHealingLayout({
    required List<String> availableCrystals,
    required List<String> targetChakras,
    String? intention,
  }) async {
    try {
      final callable = functions.httpsCallable('generateHealingLayout');
      final result = await callable.call({
        'availableCrystals': availableCrystals,
        'targetChakras': targetChakras,
        'intention': intention,
      });
      
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error generating healing layout: $e');
      return null;
    }
  }
  
  // Analyze dream with crystal correlations
  Future<Map<String, dynamic>?> analyzeDream({
    required String dreamContent,
    required List<String> userCrystals,
    DateTime? dreamDate,
    String? mood,
    String? moonPhase,
  }) async {
    try {
      final callable = functions.httpsCallable('analyzeDream');
      final result = await callable.call({
        'dreamContent': dreamContent,
        'userCrystals': userCrystals,
        'dreamDate': dreamDate?.toIso8601String(),
        'mood': mood,
        'moonPhase': moonPhase,
      });

      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error analyzing dream: $e');
      return null;
    }
  }
  
  // Get moon ritual recommendations
  Future<Map<String, dynamic>?> getMoonRituals({
    required String moonPhase,
    required List<String> userCrystals,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      final callable = functions.httpsCallable('getMoonRituals');
      final result = await callable.call({
        'moonPhase': moonPhase,
        'userCrystals': userCrystals,
        'userProfile': userProfile,
      });
      
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting moon rituals: $e');
      return null;
    }
  }
  
  // Crystal compatibility check
  Future<Map<String, dynamic>?> checkCompatibility({
    required List<String> crystalNames,
    String? purpose,
  }) async {
    try {
      final callable = functions.httpsCallable('checkCrystalCompatibility');
      final result = await callable.call({
        'crystalNames': crystalNames,
        'purpose': purpose,
      });
      
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error checking compatibility: $e');
      return null;
    }
  }
  
  // Get crystal care instructions
  Future<Map<String, dynamic>?> getCareInstructions(String crystalName) async {
    try {
      final callable = functions.httpsCallable('getCrystalCare');
      final result = await callable.call({
        'crystalName': crystalName,
      });
      
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting care instructions: $e');
      return null;
    }
  }
  
  // Get daily crystal recommendation
  Future<Map<String, dynamic>?> getDailyCrystal() async {
    try {
      final callable = functions.httpsCallable('getDailyCrystal');
      final result = await callable.call();
      
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting daily crystal: $e');
      // Return a fallback crystal with real properties
      return {
        'name': 'Clear Quartz',
        'description': 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone, Clear Quartz can be programmed with any intention and works harmoniously with all other crystals.',
        'properties': ['Amplification', 'Healing', 'Clarity', 'Energy', 'Purification'],
        'metaphysical_properties': {
          'healing_properties': ['Amplifies energy', 'Promotes clarity', 'Enhances spiritual growth'],
          'primary_chakras': ['Crown', 'All Chakras'],
        },
        'identification': {
          'name': 'Clear Quartz',
          'confidence': 95,
          'variety': 'Crystalline Quartz'
        }
      };
    }
  }
  
  // Search crystals by properties
  Future<List<Crystal>?> searchCrystals({
    String? chakra,
    String? zodiacSign,
    String? healingProperty,
    String? element,
    String? color,
  }) async {
    try {
      final callable = _functions?.httpsCallable('searchCrystals');
      if (callable == null) return [];
      final result = await callable.call({
        'chakra': chakra,
        'zodiacSign': zodiacSign,
        'healingProperty': healingProperty,
        'element': element,
        'color': color,
      });
      
      final crystals = result.data['crystals'] as List<dynamic>;
      
      return crystals.map((data) => Crystal(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        scientificName: data['scientificName'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        metaphysicalProperties: data['metaphysicalProperties'] ?? {},
        physicalProperties: data['physicalProperties'] ?? {},
        careInstructions: data['careInstructions'] ?? {},
        healingProperties: List<String>.from(data['healingProperties'] ?? []),
        chakras: List<String>.from(data['chakras'] ?? []),
        zodiacSigns: List<String>.from(data['zodiacSigns'] ?? []),
        elements: List<String>.from(data['elements'] ?? []),
        description: data['description'] ?? '',
      )).toList();
    } catch (e) {
      debugPrint('Error searching crystals: $e');
      return null;
    }
  }
}

List<String> _listifyElements(dynamic existing, dynamic fallback) {
  if (existing is List) {
    return existing.map((value) => value.toString()).where((value) => value.isNotEmpty).toList();
  }

  if (existing is String && existing.isNotEmpty) {
    return [existing];
  }

  if (fallback is List) {
    return fallback.map((value) => value.toString()).where((value) => value.isNotEmpty).toList();
  }

  if (fallback is String && fallback.isNotEmpty) {
    return [fallback];
  }

  return [];
}