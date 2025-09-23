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
      
      // Create Crystal object from result
      _lastIdentifiedCrystal = Crystal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: data['identification']['name'] ?? 'Unknown Crystal',
        scientificName: data['identification']['scientific_name'] ?? '',
        variety: data['identification']['variety'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        metaphysicalProperties: data['metaphysical_properties'] ?? {},
        physicalProperties: data['physical_properties'] ?? {},
        careInstructions: data['care_instructions'] ?? {},
        healingProperties: List<String>.from(
          data['metaphysical_properties']['healing_properties'] ?? []
        ),
        chakras: List<String>.from(
          data['metaphysical_properties']['primary_chakras'] ?? []
        ),
        zodiacSigns: List<String>.from(
          data['metaphysical_properties']['zodiac_signs'] ?? []
        ),
        elements: List<String>.from(
          data['metaphysical_properties']['elements'] ?? []
        ),
        description: data['description'] ?? '',
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

  List<String> _coerceStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item == null ? '' : item.toString())
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> _extractDailyProperties(Map<String, dynamic> data) {
    final seen = <String>{};
    final collected = <String>[];

    void addAll(List<String> values) {
      for (final value in values) {
        final lower = value.toLowerCase();
        if (seen.add(lower)) {
          collected.add(value);
        }
      }
    }

    final candidates = <List<String>>[
      _coerceStringList(data['properties']),
      _coerceStringList(data['healingProperties']),
      _coerceStringList(data['intents']),
      _coerceStringList(data['keywords']),
    ];

    for (final list in candidates) {
      if (list.isEmpty) continue;
      addAll(list);
    }

    if (collected.length > 6) {
      return collected.sublist(0, 6);
    }

    return collected;
  }

  String? _deriveDailyDescription(
    Map<String, dynamic> data,
    List<String> properties,
  ) {
    final rawName = data['name'];
    final name = rawName is String ? rawName.trim() : '';
    if (name.isEmpty) {
      return null;
    }

    if (properties.isNotEmpty) {
      final focus = properties.take(3).join(', ');
      return '$name supports $focus energy today.';
    }

    final selection = data['selectionCriteria'];
    if (selection is Map) {
      final intent = selection['intent'];
      if (intent is String && intent.trim().isNotEmpty) {
        return '$name is tuned to your focus on ${intent.trim()}.';
      }
      final mood = selection['mood'];
      if (mood is String && mood.trim().isNotEmpty) {
        return 'Lean on $name to balance feelings of ${mood.trim()}.';
      }
    }

    return 'Spend time with $name to attune to its frequency today.';
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
      final rawData = result.data;
      if (rawData is Map) {
        final data = rawData.map((key, value) => MapEntry(key.toString(), value));
        final properties = _extractDailyProperties(data);
        if (properties.isNotEmpty) {
          data['properties'] = properties;
        } else {
          data.remove('properties');
        }

        final description = data['description'];
        if (description is! String || description.trim().isEmpty) {
          final fallbackDescription = _deriveDailyDescription(data, properties);
          if (fallbackDescription != null) {
            data['description'] = fallbackDescription;
          }
        }

        return data;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting daily crystal: $e');
      // Return a fallback crystal with real properties
      return {
        'name': 'Clear Quartz',
        'description': 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone, Clear Quartz can be programmed with any intention and works harmoniously with all other crystals.',
        'properties': ['Amplification', 'Healing', 'Clarity', 'Energy', 'Purification'],
        'healingProperties': ['Amplifies energy', 'Promotes clarity', 'Enhances spiritual growth'],
        'intents': ['Amplification', 'Clarity', 'Protection'],
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
      final callable = functions.httpsCallable('searchCrystals');
      final result = await callable.call({
        'chakra': chakra,
        'zodiacSign': zodiacSign,
        'healingProperty': healingProperty,
        'element': element,
        'color': color,
      });

      final payload = result.data;
      final List<dynamic> crystals;
      if (payload is Map && payload['results'] is List) {
        crystals = List<dynamic>.from(payload['results'] as List);
      } else if (payload is List) {
        crystals = List<dynamic>.from(payload);
      } else {
        return const [];
      }

      return crystals.map((raw) {
        final data = raw is Map
            ? raw.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};
        return Crystal(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? '',
          scientificName: data['scientificName']?.toString() ?? '',
          imageUrl: data['imageUrl']?.toString() ?? '',
          metaphysicalProperties:
              data['metaphysicalProperties'] is Map
                  ? Map<String, dynamic>.from(data['metaphysicalProperties'] as Map)
                  : <String, dynamic>{},
          physicalProperties: data['physicalProperties'] is Map
              ? Map<String, dynamic>.from(data['physicalProperties'] as Map)
              : <String, dynamic>{},
          careInstructions: data['careInstructions'] is Map
              ? Map<String, dynamic>.from(data['careInstructions'] as Map)
              : <String, dynamic>{},
          healingProperties: List<String>.from(
            _coerceStringList(data['healingProperties']),
          ),
          chakras: List<String>.from(
            _coerceStringList(data['chakras']),
          ),
          zodiacSigns: List<String>.from(
            _coerceStringList(data['zodiacSigns']),
          ),
          elements: List<String>.from(
            _coerceStringList(data['elements']),
          ),
          description: data['description']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching crystals: $e');
      return null;
    }
  }
}