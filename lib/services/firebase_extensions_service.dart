import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'environment_config.dart';
import 'firebase_service.dart';

/// Firebase Extensions Service for premium features
/// Integrates multiple Google Cloud AI services via Firebase Extensions
class FirebaseExtensionsService {
  final FirebaseService _firebaseService;
  final EnvironmentConfig _config;
  
  FirebaseExtensionsService({
    required FirebaseService firebaseService,
    EnvironmentConfig? config,
  }) : _firebaseService = firebaseService,
       _config = config ?? EnvironmentConfig();

  /// 1. STORAGE-RESIZE-IMAGES Extension
  /// Automatically resize crystal photos when uploaded
  Future<Map<String, String>> uploadAndResizeCrystalImage(
    String imagePath, 
    String crystalId,
  ) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    try {
      // Upload to Firebase Storage with automatic resizing
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/uploadCrystalImage'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image_data': base64Image,
          'crystal_id': crystalId,
          'user_id': _firebaseService.currentUserId,
          'resize_options': {
            'thumbnail': '150x150',
            'medium': '400x400', 
            'large': isPremium ? '1200x1200' : '800x800', // Higher res for premium
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'original': result['original_url'],
          'thumbnail': result['thumbnail_url'],
          'medium': result['medium_url'],
          'large': result['large_url'],
        };
      } else {
        throw Exception('Image upload failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Image processing failed: $e');
    }
  }
  
  /// 2. CHATBOT with PALM API Extension
  /// AI-powered crystal guidance chatbot for premium users
  Future<String> getCrystalGuidanceChatbot({
    required String userQuery,
    required Map<String, dynamic> userContext,
    String conversationId = '',
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('AI Chatbot requires premium subscription');
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/crystalChatbot'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': userQuery,
          'user_context': {
            'name': userContext['user_name'],
            'crystals_owned': userContext['owned_crystals'],
            'birth_chart': userContext['birth_chart'],
            'recent_mood': userContext['recent_mood'],
            'subscription_tier': userContext['subscription_tier'],
          },
          'conversation_id': conversationId,
          'model_config': {
            'temperature': 0.7,
            'max_tokens': 1000,
            'personality': 'wise_crystal_mentor',
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['response'];
      } else {
        throw Exception('Chatbot query failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Chatbot service failed: $e');
    }
  }
  
  /// 3. MULTIMODAL with VERTEX AI Extension
  /// Advanced crystal identification with image + text analysis
  Future<Map<String, dynamic>> identifyCrystalMultimodal({
    required String imagePath,
    required String userDescription,
    required Map<String, dynamic> userContext,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('Multimodal crystal identification requires premium subscription');
    }
    
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/crystalMultimodalID'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image_data': base64Image,
          'user_description': userDescription,
          'user_context': userContext,
          'analysis_options': {
            'include_formation_analysis': true,
            'include_energy_reading': true,
            'include_chakra_alignment': true,
            'include_astrological_match': true,
            'include_cleansing_suggestions': true,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'crystal_identification': {
            'name': result['crystal_name'],
            'confidence': result['confidence'],
            'scientific_name': result['scientific_name'],
            'formation_type': result['formation_type'],
          },
          'metaphysical_analysis': {
            'primary_chakras': result['primary_chakras'],
            'energy_properties': result['energy_properties'],
            'astrological_alignment': result['astrological_alignment'],
            'healing_applications': result['healing_applications'],
          },
          'personalized_guidance': {
            'how_to_use': result['personalized_usage'],
            'cleansing_method': result['cleansing_method'],
            'charging_suggestions': result['charging_suggestions'],
            'meditation_guidance': result['meditation_guidance'],
          },
          'collection_integration': {
            'synergy_with_owned': result['synergy_analysis'],
            'placement_suggestions': result['placement_suggestions'],
            'ritual_combinations': result['ritual_combinations'],
          },
        };
      } else {
        throw Exception('Multimodal identification failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Multimodal analysis failed: $e');
    }
  }
  
  /// 4. TRANSLATE TEXT Extension
  /// Translate crystal information for international users
  Future<Map<String, String>> translateCrystalInfo({
    required String crystalName,
    required String description,
    required String targetLanguage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/translateContent'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': {
            'crystal_name': crystalName,
            'description': description,
          },
          'target_language': targetLanguage,
          'source_language': 'en',
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'crystal_name': result['translated_crystal_name'],
          'description': result['translated_description'],
        };
      } else {
        throw Exception('Translation failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Translation service failed: $e');
    }
  }
  
  /// 5. FIRESTORE VECTOR SEARCH Extension
  /// Find similar crystals based on properties and user preferences
  Future<List<Map<String, dynamic>>> findSimilarCrystals({
    required String crystalId,
    required Map<String, dynamic> userPreferences,
    int limit = 5,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/findSimilarCrystals'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'crystal_id': crystalId,
          'user_preferences': userPreferences,
          'search_criteria': {
            'chakra_alignment': true,
            'energy_properties': true,
            'astrological_compatibility': isPremium,
            'healing_applications': true,
          },
          'limit': isPremium ? limit : 3, // More results for premium
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(result['similar_crystals']);
      } else {
        throw Exception('Similar crystals search failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Vector search failed: $e');
    }
  }
  
  /// 6. SENTIMENT ANALYSIS Extension
  /// Analyze journal entries for emotional patterns
  Future<Map<String, dynamic>> analyzeJournalSentiment({
    required List<String> journalEntries,
    required String userId,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('Journal analysis requires premium subscription');
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/analyzeJournalSentiment'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'journal_entries': journalEntries,
          'user_id': userId,
          'analysis_options': {
            'sentiment_tracking': true,
            'emotion_patterns': true,
            'crystal_correlations': true,
            'mood_trends': true,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'overall_sentiment': result['overall_sentiment'],
          'emotion_patterns': result['emotion_patterns'],
          'crystal_effectiveness': result['crystal_effectiveness'],
          'mood_trends': result['mood_trends'],
          'recommendations': result['personalized_recommendations'],
        };
      } else {
        throw Exception('Sentiment analysis failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Sentiment analysis failed: $e');
    }
  }
  
  /// 7. TEXT-TO-SPEECH Extension
  /// Generate guided meditations and crystal activations
  Future<String> generateGuidedMeditation({
    required String crystalName,
    required String meditationType,
    required Map<String, dynamic> userContext,
  }) async {
    final isPremium = _firebaseService.currentUserProfile?.subscriptionTier != SubscriptionTier.free;
    
    if (!isPremium) {
      throw Exception('Guided meditations require premium subscription');
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/generateGuidedMeditation'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'crystal_name': crystalName,
          'meditation_type': meditationType, // 'activation', 'healing', 'manifestation'
          'user_context': userContext,
          'voice_options': {
            'language': 'en-US',
            'voice_type': 'spiritual_guide',
            'pace': 'slow',
            'background_music': true,
          },
          'duration_minutes': 10,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['audio_url']; // Cloud Storage URL for generated audio
      } else {
        throw Exception('Meditation generation failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Text-to-speech service failed: $e');
    }
  }
  
  /// Extension configuration and management
  Future<Map<String, bool>> getExtensionStatus() async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-${_config.firebaseProjectId}.cloudfunctions.net/getExtensionStatus'),
        headers: {
          'Authorization': 'Bearer ${_firebaseService.currentUserToken}',
        },
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return Map<String, bool>.from(result['extensions']);
      } else {
        return {};
      }
    } catch (e) {
      debugPrint('Extension status check failed: $e');
      return {};
    }
  }
}

/// Premium feature access controller
class PremiumExtensionsManager {
  static const Map<String, List<String>> tierFeatures = {
    'free': [
      'basic_crystal_id',
      'simple_storage',
    ],
    'premium': [
      'image_resize',
      'basic_chatbot',
      'translation',
    ],
    'pro': [
      'multimodal_analysis',
      'vector_search',
      'sentiment_analysis',
      'guided_meditations',
      'advanced_chatbot',
    ],
    'founders': [
      'all_extensions',
      'priority_processing',
      'custom_models',
    ],
  };
  
  static bool hasAccess(SubscriptionTier tier, String feature) {
    switch (tier) {
      case SubscriptionTier.free:
        return tierFeatures['free']!.contains(feature);
      case SubscriptionTier.premium:
        return tierFeatures['free']!.contains(feature) || 
               tierFeatures['premium']!.contains(feature);
      case SubscriptionTier.pro:
        return tierFeatures['free']!.contains(feature) || 
               tierFeatures['premium']!.contains(feature) ||
               tierFeatures['pro']!.contains(feature);
      case SubscriptionTier.founders:
        return true; // Founders get everything
    }
  }
}