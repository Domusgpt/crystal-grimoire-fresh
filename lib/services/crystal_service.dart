import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/crystal_model.dart';

List<String> _coerceStringList(dynamic input) {
  if (input is Iterable) {
    return input
        .map((value) => value?.toString() ?? '')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

Map<String, dynamic> _coerceMap(dynamic input) {
  if (input is Map<String, dynamic>) {
    return Map<String, dynamic>.from(input);
  }
  if (input is Map) {
    return input.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

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
      
      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};

      final identificationRaw = data['identification'];
      final identification = identificationRaw is Map
          ? Map<String, dynamic>.from(identificationRaw as Map)
          : <String, dynamic>{};

      final confidenceRaw = identification['confidence'];
      if (confidenceRaw != null) {
        final confidence = confidenceRaw is num
            ? confidenceRaw.toDouble()
            : double.tryParse(confidenceRaw.toString());
        if (confidence != null) {
          final percent =
              confidence <= 1 ? (confidence * 100) : confidence;
          identification['confidence'] =
              percent.clamp(0, 100).toDouble();
        }
      }

      final metaphysical = _coerceMap(data['metaphysical_properties']);
      final physical = _coerceMap(data['physical_properties']);
      final care = _coerceMap(data['care_instructions']);

      final healing = _coerceStringList(metaphysical['healing_properties']);
      final chakras = _coerceStringList(metaphysical['primary_chakras']);
      final zodiac = _coerceStringList(metaphysical['zodiac_signs']);
      final elements = _coerceStringList(metaphysical['elements']);

      final imageUrl = (data['imageUrl'] ??
              data['image_url'] ??
              data['image'] ??
              identification['image'])
          ?.toString() ??
          '';

      final name = (identification['name'] ?? identification['title'])
              ?.toString() ??
          'Unknown Crystal';
      final scientificName =
          (identification['scientific_name'] ??
                  identification['scientificName'] ??
                  identification['species'])
              ?.toString() ??
          '';
      final variety =
          (identification['variety'] ?? identification['type'])
              ?.toString() ??
          '';

      // Create Crystal object from result
      _lastIdentifiedCrystal = Crystal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        scientificName: scientificName,
        variety: variety,
        imageUrl: imageUrl,
        metaphysicalProperties: metaphysical,
        physicalProperties: physical,
        careInstructions: care,
        healingProperties: healing,
        chakras: chakras,
        zodiacSigns: zodiac,
        elements: elements,
        description: data['description']?.toString() ?? '',
      );

      final sanitizedMetaphysical = {
        ...metaphysical,
        'healing_properties': healing,
        'primary_chakras': chakras,
        'zodiac_signs': zodiac,
        'elements': elements,
      };

      final sanitized = Map<String, dynamic>.from(data)
        ..['identification'] = identification
        ..['metaphysical_properties'] = sanitizedMetaphysical
        ..['physical_properties'] = physical
        ..['care_instructions'] = care
        ..['imageUrl'] = imageUrl;

      _isIdentifying = false;
      notifyListeners();

      return sanitized;
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
    String? intention,
  }) async {
    try {
      final callable = functions.httpsCallable('getMoonRituals');
      final result = await callable.call({
        'moonPhase': moonPhase,
        'userCrystals': userCrystals,
        'userProfile': userProfile,
        if (intention != null) 'intention': intention,
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
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final callable = functions.httpsCallable('checkCrystalCompatibility');
      final payload = <String, dynamic>{
        'crystalNames': crystalNames,
      };

      final trimmedPurpose = purpose?.trim();
      if (trimmedPurpose != null && trimmedPurpose.isNotEmpty) {
        payload['purpose'] = trimmedPurpose;
      }

      if (userProfile != null && userProfile.isNotEmpty) {
        payload['userProfile'] = userProfile;
      }

      final result = await callable.call(payload);

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