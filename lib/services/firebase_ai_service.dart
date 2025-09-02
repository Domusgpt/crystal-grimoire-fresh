import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Firebase AI Logic Service for Crystal Identification
/// Uses official Firebase AI SDK - no custom backend needed
class FirebaseAIService {
  static late final GenerativeModel _model;
  static bool _initialized = false;

  /// Initialize Firebase AI Logic
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Create Gemini 2.0 Flash model via Firebase AI Logic
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
        systemInstruction: Content.system(_crystalIdentificationPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topP: 0.8,
          topK: 20,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
        ),
      );
      
      _initialized = true;
      print('🔮 Firebase AI Logic initialized successfully');
    } catch (e) {
      print('❌ Firebase AI Logic initialization failed: $e');
      rethrow;
    }
  }

  /// Identify crystal from image bytes
  static Future<Map<String, dynamic>> identifyCrystal({
    required Uint8List imageBytes,
    String? userQuery,
    Map<String, dynamic>? userContext,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Build personalized prompt
      final prompt = _buildPersonalizedPrompt(userQuery, userContext);
      
      // Create multimodal content (text + image)
      final content = [
        Content.multi([
          TextPart(prompt),
          InlineDataPart('image/jpeg', imageBytes),
        ])
      ];

      // Generate response using Firebase AI Logic
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('No response from AI model');
      }

      // Parse JSON response
      final result = _parseAIResponse(response.text!);
      
      // Add metadata
      result['processed_at'] = DateTime.now().toIso8601String();
      result['model_used'] = 'gemini-2.0-flash';
      result['firebase_ai_logic'] = true;
      
      return result;
      
    } catch (e) {
      print('❌ Crystal identification failed: $e');
      return {
        'error': e.toString(),
        'fallback_name': 'Unknown Crystal',
        'confidence': 0,
        'processed_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Generate spiritual guidance using user's context
  static Future<String> generateSpritualGuidance({
    required String query,
    Map<String, dynamic>? userProfile,
    List<String>? ownedCrystals,
  }) async {
    if (!_initialized) await initialize();

    try {
      final personalizedPrompt = _buildGuidancePrompt(query, userProfile, ownedCrystals);
      
      final response = await _model.generateContent([
        Content.text(personalizedPrompt)
      ]);
      
      return response.text ?? 'Unable to generate guidance at this time.';
      
    } catch (e) {
      print('❌ Spiritual guidance failed: $e');
      return 'I apologize, but I cannot provide guidance right now. Please try again later.';
    }
  }

  /// Crystal identification system prompt
  static const String _crystalIdentificationPrompt = '''
You are a master crystal healer and geologist with 30+ years of experience. You identify crystals and minerals with exceptional accuracy.

When shown a crystal image, provide comprehensive identification including:
1. Scientific mineral classification
2. Metaphysical and healing properties  
3. Chakra associations
4. Zodiac correlations
5. Care instructions
6. Spiritual significance

Always respond in the exact JSON format specified. Be confident but honest about identification certainty.
''';


  /// Build personalized prompt with user context
  static String _buildPersonalizedPrompt(String? userQuery, Map<String, dynamic>? context) {
    final buffer = StringBuffer();
    buffer.writeln('Identify this crystal and provide complete information.');
    
    if (context != null) {
      if (context['birth_chart'] != null) {
        final chart = context['birth_chart'];
        buffer.writeln('\nUser Astrological Profile:');
        buffer.writeln('Sun: ${chart['sunSign']}, Moon: ${chart['moonSign']}, Rising: ${chart['ascendant']}');
      }
      
      if (context['owned_crystals'] != null) {
        final crystals = context['owned_crystals'] as List;
        buffer.writeln('\nUser owns ${crystals.length} crystals: ${crystals.join(', ')}');
        buffer.writeln('Suggest how this crystal complements their collection.');
      }
    }
    
    if (userQuery != null && userQuery.isNotEmpty) {
      buffer.writeln('\nSpecific user question: $userQuery');
    }
    
    return buffer.toString();
  }

  /// Build spiritual guidance prompt
  static String _buildGuidancePrompt(String query, Map<String, dynamic>? profile, List<String>? crystals) {
    final buffer = StringBuffer();
    buffer.writeln('Provide wise, compassionate spiritual guidance as a crystal healing expert.');
    buffer.writeln('\nUser Question: $query');
    
    if (profile != null) {
      buffer.writeln('\nUser Profile:');
      if (profile['birth_chart'] != null) {
        buffer.writeln('Astrological signs: ${profile['birth_chart']}');
      }
      if (profile['spiritual_goals'] != null) {
        buffer.writeln('Spiritual goals: ${profile['spiritual_goals']}');
      }
    }
    
    if (crystals != null && crystals.isNotEmpty) {
      buffer.writeln('\nUser\'s Crystal Collection: ${crystals.join(', ')}');
      buffer.writeln('Reference their existing crystals in your guidance.');
    }
    
    buffer.writeln('\nProvide personalized, practical guidance in 2-3 paragraphs.');
    return buffer.toString();
  }

  /// Parse AI response and handle errors
  static Map<String, dynamic> _parseAIResponse(String response) {
    try {
      // Remove any markdown formatting
      final cleanResponse = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      return Map<String, dynamic>.from(
        json.decode(cleanResponse)
      );
    } catch (e) {
      return {
        'error': 'Failed to parse AI response',
        'raw_response': response,
        'fallback_name': 'Unknown Crystal',
      };
    }
  }
}