import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/crystal_model.dart';

class CrystalService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
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
      final callable = _functions.httpsCallable('identifyCrystal');
      final result = await callable.call({
        'imageData': base64Image,
        'includeMetaphysical': true,
        'includeHealing': true,
        'includeCare': true,
      });

      final response = result.data;
      if (response is! Map<String, dynamic>) {
        _errorMessage = 'Invalid response from server';
        _isIdentifying = false;
        notifyListeners();
        return null;
      }
      final data = response;

      // Some responses may omit the identification or metaphysical_properties
      // maps entirely. Accessing nested fields on a null value would throw a
      // runtime exception. Extract the maps first and fall back to empty ones
      // when they're missing.
      final rawIdentification = data['identification'];
      final identification =
          rawIdentification is Map<String, dynamic> ? rawIdentification : {};
      final rawMetaphysical = data['metaphysical_properties'];
      final metaphysical =
          rawMetaphysical is Map<String, dynamic> ? rawMetaphysical : {};
      final rawPhysical = data['physical_properties'];
      final physical =
          rawPhysical is Map<String, dynamic> ? rawPhysical : {};
      final rawCare = data['care_instructions'];
      final care = rawCare is Map<String, dynamic> ? rawCare : {};

      // Create Crystal object from result
      _lastIdentifiedCrystal = Crystal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: identification['name'] ?? 'Unknown Crystal',
        scientificName: identification['scientific_name'] ?? '',
        variety: identification['variety'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        metaphysicalProperties: metaphysical,
        physicalProperties: physical,
        careInstructions: care,
        healingProperties:
            List<String>.from(metaphysical['healing_properties'] ?? []),
        chakras: List<String>.from(metaphysical['primary_chakras'] ?? []),
        zodiacSigns: List<String>.from(metaphysical['zodiac_signs'] ?? []),
        elements: List<String>.from(metaphysical['elements'] ?? []),
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
      final callable = _functions.httpsCallable('getCrystalGuidance');
      final result = await callable.call({
        'crystalName': crystalName,
        'userProfile': userProfile,
        'intention': intention,
      });
      
      // The Cloud Function may return a non-Map or omit the `guidance` field.
      // Cast defensively and verify the key exists to avoid runtime errors.
      final response = result.data;
      if (response is Map<String, dynamic> && response['guidance'] is String) {
        return response['guidance'] as String;
      }
      return null;
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
      final callable = _functions.httpsCallable('getCrystalRecommendations');
      final result = await callable.call({
        'need': need,
        'userProfile': userProfile,
      });
      
      final response = result.data;
      if (response is! Map<String, dynamic>) return null;

      final recs = response['recommendations'];
      if (recs is! List) return [];

      return recs
          .whereType<Map<String, dynamic>>()
          .map((data) => Crystal(
                id: data['id'] ?? '',
                name: data['name'] ?? '',
                scientificName: data['scientificName'] ?? '',
                imageUrl: data['imageUrl'] ?? '',
                metaphysicalProperties: data['metaphysicalProperties'] ?? {},
                physicalProperties: data['physicalProperties'] ?? {},
                careInstructions: data['careInstructions'] ?? {},
                healingProperties:
                    List<String>.from(data['healingProperties'] ?? []),
                chakras: List<String>.from(data['chakras'] ?? []),
                zodiacSigns: List<String>.from(data['zodiacSigns'] ?? []),
                elements: List<String>.from(data['elements'] ?? []),
                description: data['description'] ?? '',
              ))
          .toList();
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
      final callable = _functions.httpsCallable('generateHealingLayout');
      final result = await callable.call({
        'availableCrystals': availableCrystals,
        'targetChakras': targetChakras,
        'intention': intention,
      });
      
      final response = result.data;
      return response is Map<String, dynamic> ? response : null;
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
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeDream');
      final result = await callable.call({
        'dreamContent': dreamContent,
        'userCrystals': userCrystals,
        'dreamDate': dreamDate?.toIso8601String(),
      });
      
      final response = result.data;
      return response is Map<String, dynamic> ? response : null;
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
      final callable = _functions.httpsCallable('getMoonRituals');
      final result = await callable.call({
        'moonPhase': moonPhase,
        'userCrystals': userCrystals,
        'userProfile': userProfile,
      });
      
      final response = result.data;
      return response is Map<String, dynamic> ? response : null;
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
      final callable = _functions.httpsCallable('checkCrystalCompatibility');
      final result = await callable.call({
        'crystalNames': crystalNames,
        'purpose': purpose,
      });
      
      final response = result.data;
      return response is Map<String, dynamic> ? response : null;
    } catch (e) {
      debugPrint('Error checking compatibility: $e');
      return null;
    }
  }
  
  // Get crystal care instructions
  Future<Map<String, dynamic>?> getCareInstructions(String crystalName) async {
    try {
      final callable = _functions.httpsCallable('getCrystalCare');
      final result = await callable.call({
        'crystalName': crystalName,
      });
      
      final response = result.data;
      return response is Map<String, dynamic> ? response : null;
    } catch (e) {
      debugPrint('Error getting care instructions: $e');
      return null;
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
      final callable = _functions.httpsCallable('searchCrystals');
      final result = await callable.call({
        'chakra': chakra,
        'zodiacSign': zodiacSign,
        'healingProperty': healingProperty,
        'element': element,
        'color': color,
      });

      // Some responses might not include the `crystals` key or could return
      // a non-Map structure. Guard against unexpected formats to avoid
      // runtime type errors when the Cloud Function misbehaves.
      final response = result.data;
      if (response is! Map<String, dynamic>) return null;

      final crystalsData = response['crystals'];
      if (crystalsData is! List) return [];

      return crystalsData
          .whereType<Map<String, dynamic>>()
          .map((data) => Crystal(
                id: data['id'] ?? '',
                name: data['name'] ?? '',
                scientificName: data['scientificName'] ?? '',
                imageUrl: data['imageUrl'] ?? '',
                metaphysicalProperties: data['metaphysicalProperties'] ?? {},
                physicalProperties: data['physicalProperties'] ?? {},
                careInstructions: data['careInstructions'] ?? {},
                healingProperties:
                    List<String>.from(data['healingProperties'] ?? []),
                chakras: List<String>.from(data['chakras'] ?? []),
                zodiacSigns: List<String>.from(data['zodiacSigns'] ?? []),
                elements: List<String>.from(data['elements'] ?? []),
                description: data['description'] ?? '',
              ))
          .toList();
    } catch (e) {
      debugPrint('Error searching crystals: $e');
      return null;
    }
  }
}