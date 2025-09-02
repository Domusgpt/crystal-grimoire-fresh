import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../models/crystal.dart';
import 'cache_service.dart';
import 'usage_tracker.dart';

class OpenAIService {
  static const String _baseUrl = ApiConfig.openaiBaseUrl;
  static const String _apiKey = ApiConfig.openaiApiKey;

  // The core spiritual advisor prompt
  static const String _spiritualAdvisorPrompt = '''
You are the CrystalGrimoire Spiritual Advisor - a wise, mystical guide who combines 
deep scientific knowledge of mineralogy with ancient metaphysical wisdom.

PERSONALITY & VOICE:
- Speak like a loving grandmother who's also a geology professor
- Use mystical language grounded in real crystal properties
- Always empathetic and encouraging, never judgmental
- Include poetic metaphors about light, energy, and transformation
- Begin responses with "Ah, beloved seeker..."

IDENTIFICATION APPROACH:
1. Analyze ALL visible characteristics carefully
2. Consider color, transparency, formation, luster, crystal system, and inclusions
3. Note size if measurement references are visible
4. Express confidence level clearly using these terms:
   - "I'm quite certain this is..." (HIGH confidence - 80%+)
   - "This appears to be..." (MEDIUM confidence - 60-80%)
   - "I believe this might be..." (LOW confidence - 40-60%)
   - "I need more information..." (UNCERTAIN - <40%)

WHEN UNCERTAIN:
Ask for specific additional angles or information:
- Different viewing angles (specify which: top, bottom, side, etc.)
- Close-ups of specific features or formations
- Something for scale reference
- Light transmission test (holding light behind crystal)
- Information about where it was found
- Weight or density feel

RESPONSE STRUCTURE:
1. Warm greeting with "Ah, beloved seeker..."
2. Crystal identification with confidence level
3. Key identifying features observed
4. Scientific properties (hardness, crystal system, formation)
5. Metaphysical properties (3-5 key points)
6. Chakra associations with explanations
7. Personalized spiritual guidance
8. Care and cleansing instructions
9. Mystical closing message

KNOWLEDGE SOURCES:
Base your responses on established references:
- "The Crystal Bible" by Judy Hall
- "Love Is in the Earth" by Melody  
- "The Book of Stones" by Robert Simmons & Naisha Ahsian
- Scientific mineralogy databases
- Traditional metaphysical associations

SPECIAL INSTRUCTIONS:
- If multiple crystals are possible, mention the top 2-3 candidates
- Always explain WHY you identified specific features
- Relate crystal properties to the user's spiritual journey
- Suggest specific uses based on the crystal's unique characteristics
- Include timing recommendations (moon phases, etc.) when relevant

Remember: You are their trusted spiritual guide on this crystalline journey.
''';

  // Interactive identification for uncertain cases
  static const String _interactivePrompt = '''
Continue as the CrystalGrimoire Spiritual Advisor in an ongoing identification session.

CONTEXT: This is a follow-up interaction where you previously requested more information.

APPROACH:
1. Acknowledge the new information provided
2. Combine it with previous observations
3. Provide updated identification if now confident
4. If still uncertain, ask for ONE specific additional detail
5. Build excitement about the identification process

SAMPLE RESPONSE STYLE:
"Wonderful, dear seeker! With this new perspective, I can now see the hexagonal terminations clearly. This crystalline formation, combined with the purple coloration and glassy luster you showed me earlier, confirms this is indeed Amethyst..."

Always maintain your warm, mystical voice while being educational about the identification process.
''';

  /// Identifies a crystal from images with spiritual guidance
  static Future<CrystalIdentification> identifyCrystal({
    required List<File> images,
    String? userContext,
    String? sessionId,
    String? previousContext,
  }) async {
    try {
      // Check usage limits
      if (!await UsageTracker.canIdentify()) {
        throw Exception(ApiConfig.quotaExceeded);
      }

      // Generate session ID if not provided
      sessionId ??= const Uuid().v4();

      // Check cache first
      final imageHash = await _generateImageHash(images);
      final cached = await CacheService.getCachedIdentification(imageHash);
      if (cached != null) {
        return cached;
      }

      // Prepare images
      final base64Images = await Future.wait(
        images.map((image) => _prepareImage(image)),
      );

      // Build the request
      final messages = _buildMessages(
        base64Images: base64Images,
        userContext: userContext,
        previousContext: previousContext,
      );

      final response = await _callOpenAI(messages);
      
      // Parse the response
      final identification = _parseResponse(
        response: response,
        sessionId: sessionId,
        images: images,
      );

      // Cache the result
      await CacheService.cacheIdentification(imageHash, identification);

      // Record usage
      await UsageTracker.recordUsage();

      return identification;

    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Provides spiritual guidance for a specific crystal
  static Future<String> provideSpiritualGuidance({
    required String crystalName,
    required String userNeed,
    String? birthInfo,
  }) async {
    final prompt = '''
As the CrystalGrimoire Spiritual Advisor, provide personalized guidance.

CRYSTAL: $crystalName
USER'S CURRENT NEED: "$userNeed"
${birthInfo != null ? 'BIRTH INFO: $birthInfo' : ''}

Provide:
1. Specific ways to use this crystal for their need
2. Best times and lunar phases for working with it
3. Meditation or ritual suggestions with step-by-step instructions
4. Affirmations that resonate with the crystal's energy
5. Signs that the crystal is working in their life
6. How to combine with other crystals if beneficial

Begin with "Ah, beloved seeker, your $crystalName has called to you at the perfect moment..."
''';

    return await _callOpenAIText(prompt);
  }

  /// Designs a crystal grid for specific intentions
  static Future<String> designCrystalGrid({
    required String intention,
    required List<String> availableCrystals,
    String? experience,
  }) async {
    final prompt = '''
As the CrystalGrimoire Spiritual Advisor, design a crystal grid.

INTENTION: "$intention"
AVAILABLE CRYSTALS: ${availableCrystals.join(', ')}
${experience != null ? 'USER EXPERIENCE LEVEL: $experience' : ''}

Provide:
1. Which sacred geometry pattern to use and why
2. Detailed placement for each crystal with spiritual purpose
3. Step-by-step activation ritual with timing
4. How long to leave the grid active
5. Signs the grid is working effectively
6. When and how to close/dismantle the grid

Begin with "Ah, beloved seeker, the universe has guided you to create a powerful grid for $intention..."

Include ASCII art representation of the grid layout if helpful.
''';

    return await _callOpenAIText(prompt);
  }

  // Private helper methods

  static List<Map<String, dynamic>> _buildMessages({
    required List<String> base64Images,
    String? userContext,
    String? previousContext,
  }) {
    final messages = <Map<String, dynamic>>[];

    // System prompt
    messages.add({
      'role': 'system',
      'content': previousContext != null ? _interactivePrompt : _spiritualAdvisorPrompt,
    });

    // Add previous context if continuing session
    if (previousContext != null) {
      messages.add({
        'role': 'assistant',
        'content': previousContext,
      });
    }

    // User message with images
    final userContent = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text': userContext ?? 'Please identify this crystal and provide spiritual guidance.',
      },
    ];

    // Add all images
    for (final imageData in base64Images) {
      userContent.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,$imageData',
          'detail': 'high',
        },
      });
    }

    messages.add({
      'role': 'user',
      'content': userContent,
    });

    return messages;
  }

  static Future<String> _callOpenAI(List<Map<String, dynamic>> messages) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': ApiConfig.gptModel,
        'messages': messages,
        'max_tokens': ApiConfig.maxTokens,
        'temperature': ApiConfig.temperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else if (response.statusCode == 401) {
      throw Exception(ApiConfig.invalidApiKey);
    } else {
      throw Exception('${ApiConfig.apiError} (${response.statusCode})');
    }
  }

  static Future<String> _callOpenAIText(String prompt) async {
    final messages = [
      {'role': 'system', 'content': _spiritualAdvisorPrompt},
      {'role': 'user', 'content': prompt},
    ];

    return await _callOpenAI(messages);
  }

  static Future<String> _prepareImage(File imageFile) async {
    try {
      // Ultra-simple web-safe approach - no image processing
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  static Future<String> _generateImageHash(List<File> images) async {
    final concatenatedBytes = <int>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      concatenatedBytes.addAll(bytes);
    }
    return sha256.convert(concatenatedBytes).toString();
  }

  static CrystalIdentification _parseResponse({
    required String response,
    required String sessionId,
    required List<File> images,
  }) {
    // Parse confidence level
    final confidence = _extractConfidence(response);
    
    // Check if more info is needed
    final needsMoreInfo = _checkIfNeedsMoreInfo(response);
    
    // Extract suggested angles if any
    final suggestedAngles = _extractSuggestedAngles(response);
    
    // Extract observed features
    final observedFeatures = _extractObservedFeatures(response);
    
    // Extract spiritual message
    final spiritualMessage = _extractSpiritualMessage(response);

    // Try to parse crystal information if confident enough
    Crystal? crystal;
    if (confidence.index >= ConfidenceLevel.medium.index) {
      crystal = _parseCrystalFromResponse(response, images);
    }

    return CrystalIdentification(
      sessionId: sessionId,
      fullResponse: response,
      crystal: crystal,
      confidence: confidence,
      needsMoreInfo: needsMoreInfo,
      suggestedAngles: suggestedAngles,
      observedFeatures: observedFeatures,
      spiritualMessage: spiritualMessage,
      timestamp: DateTime.now(),
    );
  }

  static ConfidenceLevel _extractConfidence(String response) {
    final lowerResponse = response.toLowerCase();
    
    if (lowerResponse.contains("i'm quite certain") || 
        lowerResponse.contains("this is definitely") ||
        lowerResponse.contains("certainly") ||
        lowerResponse.contains("without doubt")) {
      return ConfidenceLevel.high;
    } else if (lowerResponse.contains("this appears to be") ||
               lowerResponse.contains("likely") ||
               lowerResponse.contains("probably")) {
      return ConfidenceLevel.medium;
    } else if (lowerResponse.contains("might be") ||
               lowerResponse.contains("possibly") ||
               lowerResponse.contains("could be")) {
      return ConfidenceLevel.low;
    } else if (lowerResponse.contains("need more information") ||
               lowerResponse.contains("uncertain") ||
               lowerResponse.contains("difficult to determine")) {
      return ConfidenceLevel.uncertain;
    }
    
    return ConfidenceLevel.medium; // Default
  }

  static bool _checkIfNeedsMoreInfo(String response) {
    final lowerResponse = response.toLowerCase();
    return lowerResponse.contains("need more") ||
           lowerResponse.contains("could you provide") ||
           lowerResponse.contains("would help if") ||
           lowerResponse.contains("additional") ||
           lowerResponse.contains("different angle");
  }

  static List<String> _extractSuggestedAngles(String response) {
    final suggestions = <String>[];
    final lowerResponse = response.toLowerCase();
    
    if (lowerResponse.contains("side view") || lowerResponse.contains("from the side")) {
      suggestions.add("Side view");
    }
    if (lowerResponse.contains("top view") || lowerResponse.contains("from above")) {
      suggestions.add("Top view");
    }
    if (lowerResponse.contains("bottom") || lowerResponse.contains("underneath")) {
      suggestions.add("Bottom view");
    }
    if (lowerResponse.contains("close-up") || lowerResponse.contains("closer")) {
      suggestions.add("Close-up detail");
    }
    if (lowerResponse.contains("light behind") || lowerResponse.contains("translucent")) {
      suggestions.add("Light transmission test");
    }
    if (lowerResponse.contains("scale") || lowerResponse.contains("size")) {
      suggestions.add("Size reference");
    }
    
    return suggestions;
  }

  static List<String> _extractObservedFeatures(String response) {
    // This would be more sophisticated in production
    final features = <String>[];
    final lowerResponse = response.toLowerCase();
    
    if (lowerResponse.contains("purple") || lowerResponse.contains("violet")) {
      features.add("Purple coloration");
    }
    if (lowerResponse.contains("clear") || lowerResponse.contains("transparent")) {
      features.add("Transparency");
    }
    if (lowerResponse.contains("hexagonal") || lowerResponse.contains("six-sided")) {
      features.add("Hexagonal structure");
    }
    if (lowerResponse.contains("points") || lowerResponse.contains("termination")) {
      features.add("Crystal terminations");
    }
    
    return features;
  }

  static String _extractSpiritualMessage(String response) {
    // Extract the mystical/spiritual portions of the response
    final lines = response.split('\n');
    final spiritualLines = lines.where((line) => 
      line.contains('energy') || 
      line.contains('spiritual') || 
      line.contains('meditation') ||
      line.contains('healing') ||
      line.contains('chakra')
    ).toList();
    
    return spiritualLines.join('\n').trim();
  }

  static Crystal? _parseCrystalFromResponse(String response, List<File> images) {
    // This is a simplified parser - in production you'd want more sophisticated extraction
    try {
      final lines = response.split('\n');
      String name = 'Unknown Crystal';
      
      // Try to extract crystal name from the response
      for (final line in lines) {
        if (line.toLowerCase().contains('this is') || 
            line.toLowerCase().contains('appears to be')) {
          // Extract crystal name using regex or string manipulation
          final words = line.split(' ');
          final thisIndex = words.indexWhere((w) => w.toLowerCase() == 'this');
          if (thisIndex != -1 && thisIndex + 2 < words.length) {
            name = words.skip(thisIndex + 2).take(2).join(' ')
                .replaceAll(RegExp(r'[^\w\s]'), '').trim();
          }
          break;
        }
      }

      return Crystal(
        id: const Uuid().v4(),
        name: name,
        scientificName: '', // Would extract from response
        description: response,
        metaphysicalProperties: [], // Would extract from response
        healingProperties: [], // Would extract from response
        chakras: [], // Would extract from response
        colorDescription: '', // Would extract from response
        hardness: '', // Would extract from response
        formation: '', // Would extract from response
        careInstructions: '', // Would extract from response
        identificationDate: DateTime.now(),
        imageUrls: [], // Would save images and store URLs
        confidence: _extractConfidence(response),
      );
    } catch (e) {
      return null;
    }
  }

  static Exception _handleError(dynamic error) {
    if (error is SocketException) {
      return Exception(ApiConfig.networkError);
    } else if (error.toString().contains('401')) {
      return Exception(ApiConfig.invalidApiKey);
    } else if (error.toString().contains('quota')) {
      return Exception(ApiConfig.quotaExceeded);
    } else {
      return Exception(ApiConfig.apiError);
    }
  }
}