import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'astrology_service.dart';

class GuidanceService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;
  
  Map<String, dynamic>? _lastGuidance;
  Map<String, dynamic>? get lastGuidance => _lastGuidance;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Generate structured guidance according to SPEC-1 requirements
  Future<Map<String, dynamic>?> generateGuidance({
    required DateTime birthDate,
    required List<String> ownedCrystals,
    List<String>? intents,
    DateTime? currentDate,
  }) async {
    try {
      _isGenerating = true;
      _errorMessage = null;
      notifyListeners();

      // Get astrological context using local calculations
      final astroContext = AstrologyService.getGuidanceContext(
        birthDate: birthDate,
        currentDate: currentDate,
      );

      // Prepare guidance context
      final guidanceContext = {
        'astrology': astroContext,
        'crystals': ownedCrystals,
        'intents': intents ?? [],
        'timestamp': (currentDate ?? DateTime.now()).toIso8601String(),
      };

      // Call Cloud Function for AI-generated guidance
      final callable = _functions.httpsCallable('generateGuidance');
      final result = await callable.call({
        'context': guidanceContext,
        'persona': 'transcendental',
        'structured': true, // Request structured JSON output
      });

      final guidanceData = result.data as Map<String, dynamic>;

      // Validate required sections according to SPEC-1
      final structuredGuidance = _validateAndStructureGuidance(guidanceData);

      _lastGuidance = structuredGuidance;
      _isGenerating = false;
      notifyListeners();

      return structuredGuidance;
    } catch (e) {
      _errorMessage = 'Failed to generate guidance: ${e.toString()}';
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }

  /// Validate and structure guidance according to SPEC-1 requirements
  Map<String, dynamic> _validateAndStructureGuidance(Map<String, dynamic> rawGuidance) {
    // Ensure all required sections are present
    final structuredGuidance = <String, dynamic>{
      'overview': rawGuidance['overview'] ?? _generateFallbackOverview(),
      'meditation': rawGuidance['meditation'] ?? _generateFallbackMeditation(),
      'crystalLayout': rawGuidance['crystalLayout'] ?? rawGuidance['crystal_layout'] ?? _generateFallbackLayout(),
      'mantra': rawGuidance['mantra'] ?? _generateFallbackMantra(),
      'cautions': rawGuidance['cautions'] ?? _generateFallbackCautions(),
      'metadata': {
        'generatedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
        'persona': 'transcendental',
        ...rawGuidance['metadata'] ?? {},
      },
    };

    // Add safety disclaimer as required by SPEC
    structuredGuidance['disclaimer'] = 'This is spiritual guidance for wellness and reflection, not medical or professional advice.';

    return structuredGuidance;
  }

  /// Fallback methods for incomplete AI responses
  String _generateFallbackOverview() {
    return 'Today brings opportunities for spiritual growth and crystal wisdom. Trust your intuition as you work with your sacred stones.';
  }

  List<String> _generateFallbackMeditation() {
    return [
      'Find a comfortable seated position and close your eyes',
      'Take three deep breaths, feeling your connection to the Earth',
      'Hold your chosen crystal in your palm',
      'Visualize white light flowing through the crystal into your being',
      'Set your intention for healing and guidance',
      'Sit in silence for 5-10 minutes, breathing naturally',
      'When ready, slowly open your eyes and express gratitude',
    ];
  }

  Map<String, dynamic> _generateFallbackLayout() {
    return {
      'type': 'Simple Clearing',
      'duration': '15-20 minutes',
      'positions': [
        {
          'crystal': 'Clear Quartz',
          'position': 'Crown chakra (top of head)',
          'purpose': 'Amplification and clarity',
        },
        {
          'crystal': 'Amethyst',
          'position': 'Third eye (between eyebrows)',
          'purpose': 'Intuition and spiritual connection',
        },
        {
          'crystal': 'Rose Quartz',
          'position': 'Heart center',
          'purpose': 'Love and emotional healing',
        },
      ],
      'instructions': 'Lie down comfortably and place crystals as indicated. Breathe deeply and visualize healing energy flowing through each stone.',
    };
  }

  String _generateFallbackMantra() {
    return 'I am aligned with the wisdom of the crystals and the cycles of the moon.';
  }

  String _generateFallbackCautions() {
    return 'Always cleanse your crystals between uses. If you feel overwhelmed during any practice, stop and ground yourself by touching the earth or drinking water.';
  }

  /// Generate daily ritual guidance based on moon phase
  Map<String, dynamic> generateDailyRitual({
    required String moonPhase,
    required List<String> availableCrystals,
    String? intention,
  }) {
    final moonCrystals = AstrologyService.getMoonPhaseCrystals(moonPhase);
    final usableCrystals = availableCrystals.where((crystal) => 
      moonCrystals.contains(crystal)).toList();

    // If no matching crystals, use Clear Quartz as universal substitute
    if (usableCrystals.isEmpty && availableCrystals.contains('Clear Quartz')) {
      usableCrystals.add('Clear Quartz');
    }

    final ritualData = _getRitualForMoonPhase(moonPhase, usableCrystals, intention);
    
    return {
      'type': 'Daily Moon Ritual',
      'moonPhase': moonPhase,
      'ritual': ritualData,
      'crystalsUsed': usableCrystals,
      'duration': '10-15 minutes',
      'bestTime': _getBestTimeForRitual(moonPhase),
    };
  }

  /// Get ritual structure based on moon phase
  Map<String, dynamic> _getRitualForMoonPhase(String moonPhase, List<String> crystals, String? intention) {
    switch (moonPhase) {
      case 'New Moon':
        return {
          'theme': 'New Beginnings and Intention Setting',
          'steps': [
            'Light a white candle in a darkened room',
            'Hold ${crystals.isNotEmpty ? crystals.first : "your favorite crystal"} in your hands',
            'Close your eyes and breathe deeply',
            'Set your intentions for the new lunar cycle',
            'Write your goals on paper',
            'Place the paper under your crystal overnight',
          ],
          'affirmation': 'I plant seeds of intention in the fertile darkness of the new moon.',
        };
      
      case 'Full Moon':
        return {
          'theme': 'Release and Manifestation',
          'steps': [
            'Create a circle with your crystals under moonlight',
            'Stand in the center and raise your arms to the moon',
            'Express gratitude for what has manifested',
            'Release what no longer serves you',
            'Charge your crystals in the moonlight overnight',
          ],
          'affirmation': 'I release what no longer serves and embrace my highest potential.',
        };
      
      default:
        return {
          'theme': 'Balance and Reflection',
          'steps': [
            'Sit quietly with your chosen crystal',
            'Reflect on your current path and progress',
            'Ask your crystal for guidance',
            'Listen to your inner wisdom',
            'Journal any insights received',
          ],
          'affirmation': 'I am in harmony with the natural cycles of growth and rest.',
        };
    }
  }

  /// Get optimal time for ritual based on moon phase
  String _getBestTimeForRitual(String moonPhase) {
    switch (moonPhase) {
      case 'New Moon':
        return 'Just after sunset, when the sky is dark';
      case 'Full Moon':
        return 'When the moon is highest in the sky (usually midnight)';
      case 'First Quarter':
      case 'Last Quarter':
        return 'Dawn or dusk during the transition times';
      default:
        return 'Any quiet evening time when you won\'t be disturbed';
    }
  }

  /// Generate crystal care guidance
  Map<String, dynamic> generateCareGuidance(String crystalName) {
    // Basic care instructions with safety focus
    return {
      'crystal': crystalName,
      'cleansing': [
        'Rinse under running water (if water-safe)',
        'Place in moonlight overnight',
        'Use sage or palo santo smoke',
        'Bury in salt for 24 hours',
      ],
      'charging': [
        'Place in sunlight for 2-4 hours',
        'Charge under full moon overnight',
        'Place on a selenite charging plate',
        'Use sound vibrations (singing bowl)',
      ],
      'storage': 'Keep in a soft cloth away from direct sunlight when not in use',
      'safety': _getCrystalSafetyNotes(crystalName),
    };
  }

  /// Get specific safety notes for crystals
  List<String> _getCrystalSafetyNotes(String crystalName) {
    final safetyNotes = <String, List<String>>{
      'Malachite': ['Do not use in water', 'Avoid prolonged skin contact', 'Keep away from children'],
      'Pyrite': ['May tarnish in water', 'Handle with care - can be sharp'],
      'Selenite': ['Never place in water - will dissolve', 'Very soft - handle gently'],
      'Hematite': ['May rust in water', 'Can be magnetic - keep away from electronics'],
      'Fluorite': ['Fragile - handle carefully', 'Some varieties are photosensitive'],
    };

    return safetyNotes[crystalName] ?? [
      'Generally safe for regular handling',
      'Cleanse regularly between uses',
      'Store away from direct sunlight to prevent fading',
    ];
  }

  /// Clear current guidance state
  void clearGuidance() {
    _lastGuidance = null;
    _errorMessage = null;
    notifyListeners();
  }
}