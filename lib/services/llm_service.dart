import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'llm_prompt_builder.dart';
import 'environment_config.dart';

/// Production-ready LLM Service with real API integrations
/// Supports OpenAI, Claude, and Gemini with tier-based access
class LLMService {
  static const Duration _requestTimeout = Duration(seconds: 30);
  
  // API Endpoints
  static const String _openAIEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _claudeEndpoint = 'https://api.anthropic.com/v1/complete';
  static const String _geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  
  final LLMPromptBuilder promptBuilder;
  final EnvironmentConfig config;
  
  LLMService({
    required this.promptBuilder,
    required this.config,
  });
  
  /// Generate AI response based on user's subscription tier
  Future<String> generateResponse({
    required String prompt,
    required SubscriptionTier tier,
    Map<String, dynamic>? context,
  }) async {
    try {
      switch (tier) {
        case SubscriptionTier.free:
          // Use free Gemini for basic users
          return await _generateGeminiResponse(prompt);
          
        case SubscriptionTier.premium:
          return await _generateOpenAIResponse(prompt, model: 'gpt-4-turbo-preview');
          
        case SubscriptionTier.pro:
          // Try Claude first, fall back to GPT-4 if needed
          try {
            return await _generateClaudeResponse(prompt, model: 'claude-3-opus-20240229');
          } catch (e) {
            print('Claude API failed, falling back to GPT-4: $e');
            return await _generateOpenAIResponse(prompt, model: 'gpt-4-turbo-preview');
          }
          
        case SubscriptionTier.founders:
          // Use multi-model consensus for best results
          return await _generateMultiModelResponse(prompt);
      }
    } catch (e) {
      print('LLM Service Error: $e');
      throw LLMServiceException('Failed to generate AI response: $e');
    }
  }
  
  /// Generate crystal identification response with vision capabilities
  Future<Map<String, dynamic>> identifyCrystal({
    required String imageBase64,
    required Map<String, dynamic> visualFeatures,
    required UserProfile userProfile,
  }) async {
    final prompt = promptBuilder.buildIdentificationPrompt(
      imageDescription: 'Crystal image for identification',
      visualFeatures: visualFeatures,
    );
    
    try {
      // Use GPT-4 Vision for image analysis
      final response = await _generateOpenAIVisionResponse(
        prompt: prompt,
        imageBase64: imageBase64,
      );
      
      return _parseCrystalIdentification(response);
    } catch (e) {
      print('Crystal identification error: $e');
      throw LLMServiceException('Failed to identify crystal: $e');
    }
  }
  
  /// Generate personalized metaphysical guidance
  Future<String> generateGuidance({
    required String guidanceType,
    required String userQuery,
    required UserProfile userProfile,
    Map<String, dynamic>? additionalContext,
  }) async {
    final prompt = promptBuilder.buildGuidancePrompt(
      guidanceType: guidanceType,
      userQuery: userQuery,
      specificContext: additionalContext,
    );
    
    return await generateResponse(
      prompt: prompt,
      tier: userProfile.subscriptionTier,
      context: additionalContext,
    );
  }
  
  /// Generate healing session guidance
  Future<Map<String, dynamic>> generateHealingSession({
    required String chakra,
    required List<String> availableCrystals,
    required String intention,
    required UserProfile userProfile,
  }) async {
    final prompt = promptBuilder.buildHealingPrompt(
      chakra: chakra,
      availableCrystals: availableCrystals,
      healingIntention: intention,
    );
    
    final response = await generateResponse(
      prompt: prompt,
      tier: userProfile.subscriptionTier,
    );
    
    return _parseHealingSession(response);
  }
  
  /// Generate moon ritual guidance
  Future<Map<String, dynamic>> generateMoonRitual({
    required String moonPhase,
    required List<String> phaseCrystals,
    required String purpose,
    required UserProfile userProfile,
  }) async {
    final prompt = promptBuilder.buildMoonRitualPrompt(
      moonPhase: moonPhase,
      phaseCrystals: phaseCrystals,
      ritualPurpose: purpose,
    );
    
    final response = await generateResponse(
      prompt: prompt,
      tier: userProfile.subscriptionTier,
    );
    
    return _parseMoonRitual(response);
  }
  
  // Private API implementation methods
  
  Future<String> _generateOpenAIResponse(String prompt, {required String model}) async {
    final apiKey = config.openAIApiKey;
    if (apiKey.isEmpty) {
      throw LLMServiceException('OpenAI API key not configured');
    }
    
    final response = await http.post(
      Uri.parse(_openAIEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a knowledgeable crystal healing expert and metaphysical guide.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 1500,
      }),
    ).timeout(_requestTimeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw LLMServiceException('OpenAI API error: ${response.statusCode} - ${response.body}');
    }
  }
  
  Future<String> _generateOpenAIVisionResponse({
    required String prompt,
    required String imageBase64,
  }) async {
    final apiKey = config.openAIApiKey;
    if (apiKey.isEmpty) {
      throw LLMServiceException('OpenAI API key not configured');
    }
    
    final response = await http.post(
      Uri.parse(_openAIEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4-vision-preview',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$imageBase64',
                },
              },
            ],
          },
        ],
        'max_tokens': 1500,
      }),
    ).timeout(_requestTimeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw LLMServiceException('OpenAI Vision API error: ${response.statusCode}');
    }
  }
  
  Future<String> _generateClaudeResponse(String prompt, {required String model}) async {
    final apiKey = config.claudeApiKey;
    if (apiKey.isEmpty) {
      throw LLMServiceException('Claude API key not configured');
    }
    
    final response = await http.post(
      Uri.parse(_claudeEndpoint),
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'prompt': '\n\nHuman: $prompt\n\nAssistant:',
        'max_tokens_to_sample': 1500,
        'temperature': 0.7,
      }),
    ).timeout(_requestTimeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['completion'];
    } else {
      throw LLMServiceException('Claude API error: ${response.statusCode}');
    }
  }
  
  Future<String> _generateGeminiResponse(String prompt) async {
    final apiKey = config.geminiApiKey;
    if (apiKey.isEmpty) {
      throw LLMServiceException('Gemini API key not configured');
    }
    
    final response = await http.post(
      Uri.parse('$_geminiEndpoint?key=$apiKey'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': prompt,
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1500,
        },
      }),
    ).timeout(_requestTimeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw LLMServiceException('Gemini API error: ${response.statusCode}');
    }
  }
  
  /// Generate response using multiple models and synthesize the best answer
  Future<String> _generateMultiModelResponse(String prompt) async {
    final futures = <Future<String>>[];
    
    // Try all available models
    if (config.openAIApiKey.isNotEmpty) {
      futures.add(_generateOpenAIResponse(prompt, model: 'gpt-4-turbo-preview')
          .catchError((e) => 'OpenAI unavailable'));
    }
    
    if (config.claudeApiKey.isNotEmpty) {
      futures.add(_generateClaudeResponse(prompt, model: 'claude-3-opus-20240229')
          .catchError((e) => 'Claude unavailable'));
    }
    
    if (config.geminiApiKey.isNotEmpty) {
      futures.add(_generateGeminiResponse(prompt)
          .catchError((e) => 'Gemini unavailable'));
    }
    
    final responses = await Future.wait(futures);
    final validResponses = responses.where((r) => !r.contains('unavailable')).toList();
    
    if (validResponses.isEmpty) {
      throw LLMServiceException('All LLM services are unavailable');
    }
    
    // For founders tier, we could implement more sophisticated consensus
    // For now, return the longest response (usually most detailed)
    return validResponses.reduce((a, b) => a.length > b.length ? a : b);
  }
  
  // Response parsing methods
  
  Map<String, dynamic> _parseCrystalIdentification(String response) {
    // Parse the AI response into structured data
    final lines = response.split('\n');
    final result = <String, dynamic>{
      'name': '',
      'confidence': 0.0,
      'properties': [],
      'chakras': [],
      'pairings': [],
      'usage': '',
    };
    
    // Simple parsing - in production this would be more sophisticated
    for (var line in lines) {
      if (line.contains('Crystal:') || line.contains('Stone:')) {
        result['name'] = line.split(':').last.trim();
      } else if (line.contains('Confidence:')) {
        final confidenceStr = line.split(':').last.trim().replaceAll('%', '');
        result['confidence'] = double.tryParse(confidenceStr) ?? 0.0;
      } else if (line.contains('Properties:')) {
        result['properties'] = line.split(':').last.split(',').map((s) => s.trim()).toList();
      } else if (line.contains('Chakras:')) {
        result['chakras'] = line.split(':').last.split(',').map((s) => s.trim()).toList();
      }
    }
    
    return result;
  }
  
  Map<String, dynamic> _parseHealingSession(String response) {
    return {
      'steps': _extractSteps(response),
      'duration': _extractDuration(response),
      'affirmations': _extractAffirmations(response),
      'crystalPlacement': _extractCrystalPlacement(response),
      'breathingTechnique': _extractBreathingTechnique(response),
    };
  }
  
  Map<String, dynamic> _parseMoonRitual(String response) {
    return {
      'preparation': _extractSection(response, 'Preparation'),
      'ritualSteps': _extractSteps(response),
      'crystalGrid': _extractSection(response, 'Crystal Grid'),
      'timing': _extractSection(response, 'Timing'),
      'closing': _extractSection(response, 'Closing'),
    };
  }
  
  // Helper methods for parsing
  
  List<String> _extractSteps(String text) {
    final steps = <String>[];
    final lines = text.split('\n');
    for (var line in lines) {
      if (RegExp(r'^\d+\.\s').hasMatch(line.trim())) {
        steps.add(line.trim());
      }
    }
    return steps;
  }
  
  String _extractSection(String text, String sectionName) {
    final regex = RegExp('$sectionName:?\\s*([^\\n]+(?:\\n(?!\\w+:)[^\\n]+)*)', 
        caseSensitive: false, multiLine: true);
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }
  
  String _extractDuration(String text) {
    final regex = RegExp(r'(\d+)\s*minutes?', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(0) ?? '15 minutes';
  }
  
  List<String> _extractAffirmations(String text) {
    final affirmations = <String>[];
    final lines = text.split('\n');
    for (var line in lines) {
      if (line.contains('"') || line.contains('"') || line.contains('"')) {
        final cleaned = line.replaceAll(RegExp('["""]'), '').trim();
        if (cleaned.isNotEmpty) {
          affirmations.add(cleaned);
        }
      }
    }
    return affirmations;
  }
  
  Map<String, String> _extractCrystalPlacement(String text) {
    final placements = <String, String>{};
    final regex = RegExp(r'(\w+(?:\s+\w+)?)\s*[:–-]\s*([^\n,]+)', caseSensitive: false);
    final matches = regex.allMatches(text);
    for (var match in matches) {
      final crystal = match.group(1)?.trim() ?? '';
      final placement = match.group(2)?.trim() ?? '';
      if (crystal.isNotEmpty && placement.isNotEmpty) {
        placements[crystal] = placement;
      }
    }
    return placements;
  }
  
  String _extractBreathingTechnique(String text) {
    final breathingKeywords = ['breath', 'breathing', 'inhale', 'exhale'];
    final lines = text.split('\n');
    for (var line in lines) {
      if (breathingKeywords.any((keyword) => 
          line.toLowerCase().contains(keyword))) {
        return line.trim();
      }
    }
    return 'Deep, rhythmic breathing';
  }
}

/// Custom exception for LLM service errors
class LLMServiceException implements Exception {
  final String message;
  LLMServiceException(this.message);
  
  @override
  String toString() => 'LLMServiceException: $message';
}