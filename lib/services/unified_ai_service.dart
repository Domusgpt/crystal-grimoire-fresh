import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/crystal_collection.dart';
import '../services/collection_service_v2.dart';
import '../services/storage_service.dart';
import 'llm_service.dart';
import 'llm_prompt_builder.dart';
import 'environment_config.dart';

/// Unified AI Service that provides personalized responses for all features
/// This is the main service that screens use to get AI-powered guidance
class UnifiedAIService extends ChangeNotifier {
  late final LLMService _llmService;
  late LLMPromptBuilder _promptBuilder;
  final EnvironmentConfig _config;
  final StorageService _storageService;
  final CollectionServiceV2 _collectionService;
  UserProfile? _userProfile;
  
  bool _isLoading = false;
  String? _lastError;
  
  UnifiedAIService({
    required StorageService storageService,
    required CollectionServiceV2 collectionService,
    EnvironmentConfig? config,
  }) : _storageService = storageService,
       _collectionService = collectionService,
       _config = config ?? EnvironmentConfig() {
    _initializeServices();
    // Listen to collection changes
    _collectionService.addListener(_onCollectionChanged);
  }

  bool _isInitialized = false;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isConfigured => _config.enableAdvancedGuidance;
  UserProfile? get userProfile => _userProfile;
  
  Future<void> _initializeServices() async {
    if (_isInitialized) return;
    
    // Initialize user profile - use async method to load or create
    try {
      _userProfile = await _storageService.getOrCreateUserProfile();
    } catch (e) {
      print('Error loading user profile: $e');
      _userProfile = _createDefaultProfile();
    }
    
    // Create prompt builder with dependencies
    _promptBuilder = LLMPromptBuilder(
      userCollection: _collectionService.collection,
      storageService: _storageService,
      userProfile: _userProfile!,
    );
    
    // Create LLM service
    _llmService = LLMService(
      promptBuilder: _promptBuilder,
      config: _config,
    );
    
    _isInitialized = true;
    notifyListeners();
  }
  
  void _onCollectionChanged() {
    // Update prompt builder when collection changes
    _promptBuilder = LLMPromptBuilder(
      userCollection: _collectionService.collection,
      storageService: _storageService,
      userProfile: _userProfile ?? _createDefaultProfile(),
    );
    notifyListeners();
  }
  
  @override
  void dispose() {
    _collectionService.removeListener(_onCollectionChanged);
    super.dispose();
  }
  
  UserProfile _createDefaultProfile() {
    return UserProfile(
      id: 'guest',
      name: 'Guest User',
      email: 'guest@crystalgrimoire.com',
      subscriptionTier: SubscriptionTier.free,
      createdAt: DateTime.now(),
    );
  }
  
  /// Update user profile and reinitialize services
  void updateUserProfile(UserProfile profile) {
    _userProfile = profile;
    _initializeServices();
    notifyListeners();
  }
  
  /// Generate personalized crystal identification
  Future<Map<String, dynamic>> identifyCrystal({
    required String imageBase64,
    required Map<String, dynamic> visualFeatures,
  }) async {
    // Ensure initialization is complete
    await _initializeServices();
    
    if (!isConfigured) {
      throw AIServiceException('AI service not configured - missing API keys');
    }
    
    if (_userProfile == null) {
      throw AIServiceException('User profile not loaded');
    }
    
    _setLoading(true);
    try {
      final result = await _llmService.identifyCrystal(
        imageBase64: imageBase64,
        visualFeatures: visualFeatures,
        userProfile: _userProfile!,
      );
      
      // Add personalized recommendations based on user's collection
      result['personalized_suggestions'] = _generatePersonalizedSuggestions(
        result['name'],
        _collectionService.collection,
      );
      
      _clearError();
      return result;
    } catch (e) {
      _setError('Failed to identify crystal: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Generate personalized metaphysical guidance
  Future<String> getPersonalizedGuidance({
    required String guidanceType,
    required String userQuery,
    Map<String, dynamic>? additionalContext,
  }) async {
    // Ensure initialization is complete
    await _initializeServices();
    
    if (!isConfigured) {
      throw AIServiceException('AI service not configured - missing API keys');
    }
    
    if (_userProfile == null) {
      throw AIServiceException('User profile not loaded');
    }
    
    _setLoading(true);
    try {
      // Add current context to the guidance request
      final enrichedContext = {
        ...?additionalContext,
        'collection_stats': _getCollectionStats(),
        'recent_activity': _getRecentActivity(),
        'user_preferences': _userProfile!.spiritualPreferences,
      };
      
      final response = await _llmService.generateGuidance(
        guidanceType: guidanceType,
        userQuery: userQuery,
        userProfile: _userProfile!,
        additionalContext: enrichedContext,
      );
      
      _clearError();
      return response;
    } catch (e) {
      _setError('Failed to generate guidance: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Generate personalized healing session
  Future<Map<String, dynamic>> createHealingSession({
    required String chakra,
    required String intention,
  }) async {
    if (!isConfigured) {
      throw AIServiceException('AI service not configured - missing API keys');
    }
    
    if (_userProfile == null) {
      throw AIServiceException('User profile not loaded');
    }
    
    _setLoading(true);
    try {
      // Get crystals available for this chakra from user's collection
      final availableCrystals = _getChakraCrystals(chakra);
      
      final session = await _llmService.generateHealingSession(
        chakra: chakra,
        availableCrystals: availableCrystals,
        intention: intention,
        userProfile: _userProfile!,
      );
      
      // Add user-specific customizations
      session['available_crystals'] = availableCrystals;
      session['user_level'] = _getUserExperienceLevel();
      session['optimal_timing'] = _getOptimalHealingTime();
      
      _clearError();
      return session;
    } catch (e) {
      _setError('Failed to create healing session: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Generate personalized moon ritual
  Future<Map<String, dynamic>> createMoonRitual({
    required String moonPhase,
    required String purpose,
  }) async {
    if (!isConfigured) {
      throw AIServiceException('AI service not configured - missing API keys');
    }
    
    if (_userProfile == null) {
      throw AIServiceException('User profile not loaded');
    }
    
    _setLoading(true);
    try {
      // Get phase-appropriate crystals from user's collection
      final phaseCrystals = _getMoonPhaseCrystals(moonPhase);
      
      final ritual = await _llmService.generateMoonRitual(
        moonPhase: moonPhase,
        phaseCrystals: phaseCrystals,
        purpose: purpose,
        userProfile: _userProfile!,
      );
      
      // Add location-specific timing
      ritual['optimal_time'] = _calculateOptimalRitualTime();
      ritual['available_crystals'] = phaseCrystals;
      ritual['experience_level'] = _getUserExperienceLevel();
      
      _clearError();
      return ritual;
    } catch (e) {
      _setError('Failed to create moon ritual: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Generate journal prompts based on mood and crystals
  Future<List<String>> generateJournalPrompts({
    required String mood,
    required String journalType,
    List<String>? recentCrystals,
  }) async {
    if (!isConfigured) {
      return _getDefaultJournalPrompts(mood, journalType);
    }
    
    if (_userProfile == null) {
      throw AIServiceException('User profile not loaded');
    }
    
    _setLoading(true);
    try {
      final prompt = _promptBuilder.buildJournalPrompt(
        mood: mood,
        recentCrystals: recentCrystals ?? _getRecentlyUsedCrystals(),
        journalType: journalType,
      );
      
      final response = await _llmService.generateResponse(
        prompt: prompt,
        tier: _userProfile!.subscriptionTier,
      );
      
      _clearError();
      return _parseJournalPrompts(response);
    } catch (e) {
      _setError('Failed to generate journal prompts: $e');
      return _getDefaultJournalPrompts(mood, journalType);
    } finally {
      _setLoading(false);
    }
  }
  
  /// Get crystal recommendations for marketplace browsing
  Future<List<Map<String, dynamic>>> getMarketplaceRecommendations() async {
    if (!isConfigured) {
      return _getDefaultMarketplaceRecommendations();
    }
    
    if (_userProfile == null) {
      return _getDefaultMarketplaceRecommendations();
    }
    
    _setLoading(true);
    try {
      final context = _promptBuilder.buildUserContext();
      final prompt = '''
Based on this user's profile and collection, recommend 5 crystals they should consider buying:

${context.toString()}

Provide recommendations in this format:
Crystal: [Name]
Reason: [Why this crystal fits their profile]
Synergy: [How it works with their existing crystals]
Price Range: [Estimated fair price]
''';
      
      final response = await _llmService.generateResponse(
        prompt: prompt,
        tier: _userProfile!.subscriptionTier,
      );
      
      _clearError();
      return _parseMarketplaceRecommendations(response);
    } catch (e) {
      _setError('Failed to generate marketplace recommendations: $e');
      return _getDefaultMarketplaceRecommendations();
    } finally {
      _setLoading(false);
    }
  }
  
  // Helper methods for data extraction and formatting
  
  List<String> _getChakraCrystals(String chakra) {
    final chakraCrystals = {
      'Crown': ['Clear Quartz', 'Amethyst', 'Selenite', 'Lepidolite'],
      'Third Eye': ['Lapis Lazuli', 'Sodalite', 'Fluorite', 'Labradorite'],
      'Throat': ['Blue Lace Agate', 'Aquamarine', 'Turquoise', 'Celestite'],
      'Heart': ['Rose Quartz', 'Green Aventurine', 'Rhodonite', 'Malachite'],
      'Solar Plexus': ['Citrine', 'Yellow Jasper', 'Tiger Eye', 'Pyrite'],
      'Sacral': ['Carnelian', 'Orange Calcite', 'Sunstone', 'Moonstone'],
      'Root': ['Red Jasper', 'Black Tourmaline', 'Hematite', 'Smoky Quartz'],
    };
    
    final availableCrystals = chakraCrystals[chakra] ?? [];
    return _collectionService.collection
        .where((entry) => availableCrystals.contains(entry.crystal.name))
        .map((entry) => entry.crystal.name)
        .toList();
  }
  
  List<String> _getMoonPhaseCrystals(String moonPhase) {
    final phaseCrystals = {
      'New Moon': ['Black Moonstone', 'Labradorite', 'Clear Quartz'],
      'Waxing Crescent': ['Citrine', 'Green Aventurine', 'Pyrite'],
      'First Quarter': ['Carnelian', 'Red Jasper', 'Tiger Eye'],
      'Waxing Gibbous': ['Rose Quartz', 'Rhodonite', 'Pink Tourmaline'],
      'Full Moon': ['Selenite', 'Moonstone', 'Clear Quartz'],
      'Waning Gibbous': ['Amethyst', 'Lepidolite', 'Blue Lace Agate'],
      'Last Quarter': ['Smoky Quartz', 'Black Tourmaline', 'Obsidian'],
      'Waning Crescent': ['Selenite', 'Celestite', 'Blue Calcite'],
    };
    
    final availableCrystals = phaseCrystals[moonPhase] ?? [];
    return _collectionService.collection
        .where((entry) => availableCrystals.contains(entry.crystal.name))
        .map((entry) => entry.crystal.name)
        .toList();
  }
  
  List<String> _getRecentlyUsedCrystals() {
    final recentlyUsed = _collectionService.getRecentlyUsed(limit: 5);
    return recentlyUsed.map((entry) => entry.crystal.name).toList();
  }
  
  Map<String, dynamic> _getCollectionStats() {
    final collection = _collectionService.collection;
    return {
      'total_crystals': collection.length,
      'most_used': collection.isNotEmpty 
        ? collection.reduce((a, b) => a.usageCount > b.usageCount ? a : b).crystal.name
        : 'None',
      'recent_additions': collection
          .where((e) => DateTime.now().difference(e.dateAdded).inDays < 30)
          .length,
      'usage_frequency': collection.isNotEmpty
        ? collection.map((e) => e.usageCount).reduce((a, b) => a + b) / collection.length
        : 0.0,
    };
  }
  
  Map<String, dynamic> _getRecentActivity() {
    final now = DateTime.now();
    final usageLogs = _collectionService.usageLogs;
    
    // Count crystals used today
    final usedToday = usageLogs
        .where((log) => log.dateTime.day == now.day && 
                       log.dateTime.month == now.month &&
                       log.dateTime.year == now.year)
        .map((log) => log.collectionEntryId)
        .toSet()
        .length;
    
    // Count crystals used this week
    final usedThisWeek = usageLogs
        .where((log) => now.difference(log.dateTime).inDays < 7)
        .map((log) => log.collectionEntryId)
        .toSet()
        .length;
    
    // Get last crystal used
    String lastCrystalUsed = 'None';
    if (usageLogs.isNotEmpty) {
      final sortedLogs = List.from(usageLogs)
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final lastUsedId = sortedLogs.first.collectionEntryId;
      final entry = _collectionService.collection
          .firstWhere((e) => e.id == lastUsedId, 
                      orElse: () => _collectionService.collection.first);
      lastCrystalUsed = entry.crystal.name;
    }
    
    return {
      'crystals_used_today': usedToday,
      'crystals_used_this_week': usedThisWeek,
      'last_crystal_used': lastCrystalUsed,
    };
  }
  
  String _getUserExperienceLevel() {
    if (_userProfile == null) return 'Beginner';
    
    final daysSinceJoining = DateTime.now().difference(_userProfile!.createdAt).inDays;
    final collectionSize = _collectionService.collection.length;
    final totalUsage = _collectionService.collection
        .map((e) => e.usageCount)
        .fold(0, (a, b) => a + b);
    
    if (daysSinceJoining > 365 && collectionSize > 20 && totalUsage > 100) {
      return 'Advanced';
    } else if (daysSinceJoining > 90 && collectionSize > 10 && totalUsage > 30) {
      return 'Intermediate';
    } else {
      return 'Beginner';
    }
  }
  
  String _getOptimalHealingTime() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Morning (6-10 AM) - Energizing phase';
    if (hour < 15) return 'Midday (10 AM-3 PM) - Peak energy phase';
    if (hour < 20) return 'Evening (3-8 PM) - Transition phase';
    return 'Night (8 PM-6 AM) - Restorative phase';
  }
  
  String _calculateOptimalRitualTime() {
    // This would integrate with actual lunar calculation APIs
    final hour = DateTime.now().hour;
    if (hour >= 20 || hour <= 4) {
      return 'Optimal: Tonight between 8 PM - 4 AM';
    } else {
      return 'Optimal: Tomorrow night between 8 PM - 4 AM';
    }
  }
  
  Map<String, dynamic> _generatePersonalizedSuggestions(
      String identifiedCrystal, List<CollectionEntry> userCollection) {
    // Generate suggestions based on the identified crystal and user's collection
    return {
      'ritual_ideas': [
        'Create a crystal grid with your $identifiedCrystal',
        'Meditate with $identifiedCrystal during your morning routine',
        'Place $identifiedCrystal on your nightstand for dream work',
      ],
      'pairing_suggestions': userCollection.take(3).map((entry) => 
        'Combine with your ${entry.crystal.name} for enhanced energy').toList(),
      'care_instructions': [
        'Cleanse $identifiedCrystal under moonlight monthly',
        'Charge with selenite or clear quartz between uses',
        'Set specific intentions when working with this crystal',
      ],
    };
  }
  
  // Fallback methods for when AI is unavailable
  
  List<String> _getDefaultJournalPrompts(String mood, String journalType) {
    final defaultPrompts = {
      'gratitude': [
        'What three things am I most grateful for today?',
        'How did my crystals support me today?',
        'What positive energy did I notice around me?',
      ],
      'reflection': [
        'What emotions came up for me today?',
        'How can I better align with my intentions?',
        'What crystal energy do I need more of right now?',
      ],
      'intention': [
        'What do I want to manifest this week?',
        'How can my crystal collection support my goals?',
        'What limiting beliefs am I ready to release?',
      ],
    };
    
    return defaultPrompts[journalType] ?? defaultPrompts['reflection']!;
  }
  
  List<Map<String, dynamic>> _getDefaultMarketplaceRecommendations() {
    return [
      {
        'name': 'Rose Quartz',
        'reason': 'Perfect for heart healing and self-love',
        'synergy': 'Complements any collection with gentle love energy',
        'price_range': '\$15-30',
      },
      {
        'name': 'Clear Quartz',
        'reason': 'Universal amplifier for all intentions',
        'synergy': 'Enhances the power of all other crystals',
        'price_range': '\$10-25',
      },
      {
        'name': 'Amethyst',
        'reason': 'Spiritual protection and enhanced intuition',
        'synergy': 'Perfect for meditation and crown chakra work',
        'price_range': '\$20-40',
      },
    ];
  }
  
  // Response parsing helpers
  
  List<String> _parseJournalPrompts(String response) {
    final prompts = <String>[];
    final lines = response.split('\n');
    
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('?') && !trimmed.startsWith('Note:')) {
        prompts.add(trimmed.replaceAll(RegExp(r'^[\d\-\*\.\s]+'), ''));
      }
    }
    
    return prompts.isNotEmpty ? prompts : _getDefaultJournalPrompts('neutral', 'reflection');
  }
  
  List<Map<String, dynamic>> _parseMarketplaceRecommendations(String response) {
    final recommendations = <Map<String, dynamic>>[];
    final sections = response.split('Crystal:');
    
    for (var section in sections.skip(1)) {
      final lines = section.split('\n');
      if (lines.length >= 4) {
        recommendations.add({
          'name': lines[0].trim(),
          'reason': lines.firstWhere((l) => l.contains('Reason:'), orElse: () => 'Reason: Great addition to any collection').split('Reason:')[1].trim(),
          'synergy': lines.firstWhere((l) => l.contains('Synergy:'), orElse: () => 'Synergy: Works well with existing crystals').split('Synergy:')[1].trim(),
          'price_range': lines.firstWhere((l) => l.contains('Price'), orElse: () => 'Price Range: \$20-40').split(':')[1].trim(),
        });
      }
    }
    
    return recommendations.isNotEmpty ? recommendations : _getDefaultMarketplaceRecommendations();
  }
  
  // State management helpers
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }
  
  void _clearError() {
    _lastError = null;
    notifyListeners();
  }
  
  /// Check service health and configuration
  Map<String, dynamic> getServiceStatus() {
    return {
      'configured': isConfigured,
      'user_loaded': _userProfile != null,
      'collection_size': _collectionService.collection.length,
      'last_error': _lastError,
      'loading': _isLoading,
      'config_summary': _config.getConfigSummary(),
    };
  }
}

/// Exception for AI service errors
class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  
  @override
  String toString() => 'AIServiceException: $message';
}

/// Extension to easily access UnifiedAIService from context
extension UnifiedAIServiceContext on BuildContext {
  UnifiedAIService get aiService => read<UnifiedAIService>();
  UnifiedAIService get aiServiceWatch => watch<UnifiedAIService>();
}