import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/crystal_collection.dart';
import 'environment_config.dart';
import 'firebase_service.dart';
import 'unified_data_service.dart';

/// Enhanced AI Service for premium users with multiple LLM models
/// Uses Firebase Blaze Cloud Functions to access premium APIs
class EnhancedAIService extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final UnifiedDataService _unifiedDataService;
  final EnvironmentConfig _config;
  
  EnhancedAIService({
    required FirebaseService firebaseService,
    required UnifiedDataService unifiedDataService,
    EnvironmentConfig? config,
  }) : _firebaseService = firebaseService,
       _unifiedDataService = unifiedDataService,
       _config = config ?? EnvironmentConfig();
  
  /// Available AI models for different use cases
  enum AIModel {
    geminiPro,     // Best for crystal identification and visual analysis
    gpt4,          // Best for spiritual guidance and complex reasoning
    claude,        // Best for nuanced spiritual and philosophical content
    geminiFlash,   // Fast responses for quick questions
  }
  
  /// Get automatic crystal identification with full metaphysical classification
  Future<Map<String, dynamic>> identifyCrystalPremium({
    required String imagePath,
    required Map<String, dynamic> userContext,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('Premium crystal identification requires subscription upgrade');
    }
    
    // Use Gemini Pro for visual analysis and auto-classification
    return await _callEnhancedAI(
      model: AIModel.geminiPro,
      prompt: _buildAutoClassificationPrompt(userContext),
      imagePath: imagePath,
      category: 'crystal_auto_classification',
    );
  }
  
  /// Get deep spiritual guidance using Claude for nuanced responses
  Future<Map<String, dynamic>> getSpiritualGuidance({
    required String query,
    required Map<String, dynamic> userContext,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('Advanced spiritual guidance requires subscription upgrade');
    }
    
    // Use Claude for deep spiritual insights
    return await _callEnhancedAI(\n      model: AIModel.claude,\n      prompt: _buildSpiritualGuidancePrompt(query, userContext),\n      category: 'spiritual_guidance',\n    );\n  }\n  \n  /// Get personalized healing recommendations using GPT-4\n  Future<Map<String, dynamic>> getHealingRecommendations({\n    required String concern,\n    required Map<String, dynamic> userContext,\n  }) async {\n    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;\n    \n    if (!isPremium) {\n      throw Exception('Personalized healing requires subscription upgrade');\n    }\n    \n    // Use GPT-4 for complex reasoning about healing\n    return await _callEnhancedAI(\n      model: AIModel.gpt4,\n      prompt: _buildHealingPrompt(concern, userContext),\n      category: 'healing_guidance',\n    );\n  }\n  \n  /// Get quick crystal recommendations using Gemini Flash\n  Future<Map<String, dynamic>> getQuickRecommendations({\n    required String mood,\n    required Map<String, dynamic> userContext,\n  }) async {\n    // Use Gemini Flash for fast responses (available to all users)\n    return await _callEnhancedAI(\n      model: AIModel.geminiFlash,\n      prompt: _buildQuickRecommendationPrompt(mood, userContext),\n      category: 'quick_recommendations',\n    );\n  }\n  \n  /// Call enhanced AI through Firebase Cloud Functions\n  Future<Map<String, dynamic>> _callEnhancedAI({\n    required AIModel model,\n    required String prompt,\n    required String category,\n    String? imagePath,\n  }) async {\n    try {\n      final endpoint = _getModelEndpoint(model);\n      \n      final requestData = {\n        'model': model.name,\n        'prompt': prompt,\n        'category': category,\n        'user_id': _firebaseService.currentUserId,\n        'subscription_tier': _firebaseService.currentUserProfile?.subscriptionTier.name ?? 'free',\n      };\n      \n      // Add image data for visual models\n      if (imagePath != null && (model == AIModel.geminiPro)) {\n        requestData['image_data'] = await _encodeImage(imagePath);\n      }\n      \n      // Call Firebase Cloud Function\n      final response = await _firebaseService.callEnhancedAPI(endpoint, requestData);\n      \n      return {\n        'success': true,\n        'response': response['response'] ?? 'No response received',\n        'model_used': model.name,\n        'tokens_used': response['tokens_used'] ?? 0,\n        'cost': response['cost'] ?? 0.0,\n        'processing_time': response['processing_time'] ?? 0,\n      };\n      \n    } catch (e) {\n      debugPrint('Enhanced AI call failed: $e');\n      return {\n        'success': false,\n        'error': e.toString(),\n        'fallback_used': false,\n      };\n    }\n  }\n  \n  /// Build crystal identification prompt with user context\n  String _buildCrystalIdentificationPrompt(Map<String, dynamic> userContext) {\n    final ownedCrystals = List<String>.from(userContext['owned_crystals']?.map((c) => c['name']) ?? []);\n    \n    return '''\nYou are an expert crystal identifier and spiritual advisor. Analyze this crystal image with deep expertise.\n\nUSER PROFILE:\n- Name: ${userContext['user_name']}\n- Birth Chart: ${userContext['birth_chart']}\n- Current Collection: ${ownedCrystals.join(', ')}\n- Collection Size: ${userContext['crystal_count']} crystals\n- Recent Mood: ${userContext['recent_mood']}\n- Subscription: ${userContext['subscription_tier']}\n\nIDENTIFICATION REQUIREMENTS:\n1. Identify the crystal with 95%+ accuracy\n2. Explain how it complements their existing collection\n3. Relate properties to their astrological profile\n4. Suggest specific ways to use it based on their recent mood\n5. Recommend cleansing and charging methods\n6. Explain any unique properties or formations visible\n\nProvide comprehensive, personalized insights that feel like guidance from an expert who knows this user personally.\n''';\n  }\n  \n  /// Build spiritual guidance prompt with full user context\n  String _buildSpiritualGuidancePrompt(String query, Map<String, dynamic> userContext) {\n    final ownedCrystals = userContext['owned_crystals'] ?? [];\n    final birthChart = userContext['birth_chart'] ?? {};\n    \n    return '''\nYou are a wise spiritual mentor who knows this person deeply. Provide guidance that draws from their complete spiritual profile.\n\nPERSONAL CONTEXT:\n- Name: ${userContext['user_name']}\n- Astrological Profile: ${birthChart}\n- Crystal Collection: ${ownedCrystals.map((c) => '${c['name']} (${c['usage_count']} uses)').join(', ')}\n- Recent Emotional State: ${userContext['recent_mood']}\n- Spiritual Journey Stage: ${userContext['subscription_tier']} practitioner\n- Recent Activity: ${userContext['recent_activity']}\n\nGUIDANCE REQUEST: \"${query}\"\n\nPROVIDE:\n1. Personalized guidance that references their specific crystals\n2. Astrological insights relevant to their birth chart\n3. Practical next steps they can take today\n4. Specific crystals from their collection to work with\n5. Meditation or ritual suggestions based on their current state\n6. Long-term spiritual development advice\n\nSpeak as a mentor who has watched their journey and knows their stones intimately.\n''';\n  }\n  \n  /// Build healing prompt with medical disclaimers\n  String _buildHealingPrompt(String concern, Map<String, dynamic> userContext) {\n    final healingCrystals = userContext['owned_crystals']?.where((c) => \n      c['intentions']?.toLowerCase()?.contains('healing') == true ||\n      c['type']?.toLowerCase()?.contains('healing') == true\n    ).toList() ?? [];\n    \n    return '''\nYou are a holistic wellness advisor specializing in crystal healing. Address this concern with their personal collection.\n\nDISCLAIMER: This is complementary wellness guidance, not medical advice. Always consult healthcare professionals for medical concerns.\n\nUSER PROFILE:\n- Name: ${userContext['user_name']}\n- Healing Crystals Owned: ${healingCrystals.map((c) => c['name']).join(', ')}\n- Current Emotional State: ${userContext['recent_mood']}\n- Astrological Considerations: ${userContext['birth_chart']}\n\nCONCERN: \"${concern}\"\n\nPROVIDE PERSONALIZED HEALING GUIDANCE:\n1. Specific crystals from their collection for this concern\n2. Detailed placement and usage instructions\n3. Complementary practices (meditation, breathwork)\n4. Chakra work if relevant to their astrological profile\n5. Timeline and what to expect\n6. When to seek additional support\n\nFocus on their actual crystals and practical steps they can implement immediately.\n''';\n  }\n  \n  /// Build quick recommendation prompt\n  String _buildQuickRecommendationPrompt(String mood, Map<String, dynamic> userContext) {\n    return '''\nQuick crystal guidance for current mood: ${mood}\n\nUser has: ${userContext['owned_crystals']?.map((c) => c['name']).join(', ') ?? 'No crystals yet'}\n\nProvide:\n1. Best crystal from their collection for this mood\n2. Simple 2-minute practice\n3. One affirmation\n\nKeep it concise and actionable.\n''';\n  }\n  \n  /// Get Cloud Function endpoint for each model\n  String _getModelEndpoint(AIModel model) {\n    switch (model) {\n      case AIModel.geminiPro:\n        return 'geminiProAnalysis';\n      case AIModel.gpt4:\n        return 'gpt4Guidance';\n      case AIModel.claude:\n        return 'claudeWisdom';\n      case AIModel.geminiFlash:\n        return 'geminiFlashQuick';\n    }\n  }\n  \n  /// Encode image for API\n  Future<String> _encodeImage(String imagePath) async {\n    try {\n      final file = File(imagePath);\n      final bytes = await file.readAsBytes();\n      return base64Encode(bytes);\n    } catch (e) {\n      throw Exception('Failed to encode image: $e');\n    }\n  }\n  \n  /// Get usage statistics for premium users\n  Future<Map<String, dynamic>> getUsageStats() async {\n    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;\n    \n    if (!isPremium) {\n      return {\n        'daily_limit': 5,\n        'used_today': 0, // This would be tracked in storage\n        'premium_features': false,\n      };\n    }\n    \n    try {\n      return await _firebaseService.callEnhancedAPI('getUsageStats', {});\n    } catch (e) {\n      return {\n        'error': 'Could not fetch usage stats',\n        'premium_features': true,\n      };\n    }\n  }\n  \n  /// Test different models and return comparison\n  Future<Map<String, dynamic>> testModelComparison(String query, Map<String, dynamic> userContext) async {\n    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;\n    \n    if (!isPremium) {\n      throw Exception('Model comparison requires premium subscription');\n    }\n    \n    // Test all models with the same query\n    final results = <String, dynamic>{};\n    \n    for (final model in AIModel.values) {\n      try {\n        final response = await _callEnhancedAI(\n          model: model,\n          prompt: query,\n          category: 'comparison_test',\n        );\n        results[model.name] = response;\n      } catch (e) {\n        results[model.name] = {'error': e.toString()};\n      }\n    }\n    \n    return results;\n  }\n}