import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/crystal_model.dart';

class CrystalService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Dio _dio = Dio();
  
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
      
      final data = result.data as Map<String, dynamic>;
      final meta = data['metaphysical_properties'] as Map<String, dynamic>?;

      // Create Crystal object from result
      _lastIdentifiedCrystal = Crystal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: data['identification']['name'] ?? 'Unknown Crystal',
        scientificName: data['identification']['scientific_name'] ?? '',
        variety: data['identification']['variety'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        metaphysicalProperties: meta ?? {},
        physicalProperties: data['physical_properties'] ?? {},
        careInstructions: data['care_instructions'] ?? {},
        healingProperties:
            List<String>.from(meta?['healing_properties'] ?? const []),
        chakras:
            List<String>.from(meta?['primary_chakras'] ?? const []),
        zodiacSigns:
            List<String>.from(meta?['zodiac_signs'] ?? const []),
        elements: List<String>.from(meta?['elements'] ?? const []),
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
      final callable = _functions.httpsCallable('getCrystalRecommendations');
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
      final callable = _functions.httpsCallable('generateHealingLayout');
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
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeDream');
      final result = await callable.call({
        'dreamContent': dreamContent,
        'userCrystals': userCrystals,
        'dreamDate': dreamDate?.toIso8601String(),
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
      final callable = _functions.httpsCallable('getMoonRituals');
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
      final callable = _functions.httpsCallable('checkCrystalCompatibility');
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
      final callable = _functions.httpsCallable('getCrystalCare');
      final result = await callable.call({
        'crystalName': crystalName,
      });
      
      return result.data as Map<String, dynamic>;
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