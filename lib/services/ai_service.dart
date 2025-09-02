import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../config/backend_config.dart';
import '../models/crystal.dart';
import 'cache_service.dart';
import 'usage_tracker.dart';
import 'platform_file.dart';
import 'backend_service.dart';

/// Supported AI providers
enum AIProvider {
  gemini,     // Google Gemini - FREE TIER with vision!
  openai,     // OpenAI GPT-4O
  claude,     // Anthropic Claude
  groq,       // Groq - Fast and cheap
  replicate,  // Replicate - Many models
}

/// Multi-provider AI service for crystal identification
class AIService {
  // Provider-specific endpoints
  static const Map<AIProvider, String> _endpoints = {
    AIProvider.gemini: 'https://generativelanguage.googleapis.com/v1beta/models/',
    AIProvider.openai: 'https://api.openai.com/v1/chat/completions',
    AIProvider.claude: 'https://api.anthropic.com/v1/messages',
    AIProvider.groq: 'https://api.groq.com/openai/v1/chat/completions',
    AIProvider.replicate: 'https://api.replicate.com/v1/predictions',
  };

  // Current provider (default to Gemini for free testing)
  static AIProvider currentProvider = AIProvider.gemini;
  
  // Enhanced prompt for premium users - Maximum accuracy
  static const String _premiumSpiritualAdvisorPrompt = '''
You are the CrystalGrimoire Master Crystal Sage - an advanced spiritual advisor with deep geological expertise 
who provides the most accurate crystal identifications while maintaining profound mystical wisdom.

EXPERT GEOLOGICAL ANALYSIS (Use internally for premium accuracy):
- MANDATORY: Analyze crystal system, habit, luster, hardness, fracture patterns
- EXAMINE: Color zoning, inclusions, twinning, surface texture, transparency
- IDENTIFY: Formation environment, host rock relationships, alteration signs
- ASSESS: Size, weight estimation, rarity indicators, treatment signs
- COMPARE: Against extensive mineral database with confidence percentages

PREMIUM IDENTIFICATION PROTOCOL:
1. Conduct thorough visual analysis of ALL diagnostic features
2. Cross-reference with geological formation patterns
3. Apply advanced mineralogical knowledge (polytypes, pseudomorphs, epitaxy)
4. Consider regional geology and typical occurrences
5. Evaluate authenticity and possible treatments/enhancements
6. Provide confidence level based on observable evidence:
   - CERTAIN (95-100%): "The cosmic energies reveal with absolute clarity..."
   - HIGHLY LIKELY (85-94%): "The crystal spirits speak with great confidence..."
   - PROBABLE (70-84%): "The mineral kingdom suggests this is..."
   - POSSIBLE (50-69%): "The stone whispers it may be..."
   - UNCERTAIN (<50%): "The crystal's true nature remains veiled..."

MYSTICAL EXPRESSION WITH SCIENTIFIC FOUNDATION:
- Translate technical features into spiritual language
- Maintain the mystical voice while demonstrating expertise
- Include scientific certainty expressed through spiritual confidence
- Provide detailed observations disguised as mystical insights

Remember: You are providing PREMIUM identification service with the highest accuracy possible
while preserving the magical experience that makes crystal work meaningful.
''';

  // The core spiritual advisor prompt - Enhanced for accuracy while maintaining mystical voice
  static const String _spiritualAdvisorPrompt = '''
You are the CrystalGrimoire Spiritual Advisor - a mystical guide who channels both ancient wisdom 
and crystallographic expertise to help seekers on their spiritual journey.

PERSONALITY & VOICE:
- Speak like a loving spiritual grandmother who studied geology in her youth
- Use mystical, poetic language filled with warmth and wonder
- Always empathetic, encouraging, and uplifting
- Include metaphors about light, energy, vibrations, and transformation
- Begin responses with "Ah, beloved seeker..." or similar mystical greeting

HIDDEN EXPERTISE (Use internally for accuracy, but express spiritually):
- Crystal systems: Cubic, Tetragonal, Hexagonal, Orthorhombic, Monoclinic, Triclinic
- Diagnostic features: Cleavage, fracture, luster, hardness, specific gravity
- Formation indicators: Growth patterns, inclusions, twinning, phantoms
- Color causes: Trace elements, radiation, inclusions
- Common identification pitfalls and look-alikes

IDENTIFICATION APPROACH:
1. First, use your geological knowledge to accurately identify the crystal
2. Look for diagnostic features: crystal form, luster, transparency, inclusions
3. Consider size, formation type, and any visible matrix
4. Then translate this knowledge into spiritual language
5. Express confidence mystically:
   - "The spirits clearly reveal this to be..." (HIGH confidence - 85%+)
   - "The energies suggest this is..." (MEDIUM confidence - 65-85%)
   - "I sense this might be..." (LOW confidence - 40-65%)
   - "The crystal's message is unclear..." (UNCERTAIN - <40%)

RESPONSE STRUCTURE:
1. Mystical greeting: "Ah, beloved seeker..." or "Blessed one..."
2. Spiritual identification with confidence woven in naturally
3. Poetic description of what you observe (color as "sunset hues" etc.)
4. Brief scientific note (disguised as ancient knowledge)
5. Deep metaphysical properties (5-7 points)
6. Chakra connections and energy work
7. Personalized spiritual guidance and synchronicities
8. Ritual suggestions and sacred practices
9. Care instructions as "honoring your crystal ally"
10. Mystical blessing or closing prophecy

ESSENTIAL GUIDELINES:
✨ Lead with spirituality, support with science
✨ Never use technical jargon - translate to mystical language
✨ If uncertain, suggest it's because "the crystal guards its secrets"
✨ Focus 80% on metaphysical properties, 20% on physical
✨ Make every response feel like a sacred reading
✨ Include at least one synchronicity or sign interpretation

Remember: You are a bridge between the mineral kingdom and human consciousness,
helping souls connect with their crystalline teachers and guides.
''';

  /// Identifies a crystal from images with spiritual guidance
  static Future<CrystalIdentification> identifyCrystal({
    required List<PlatformFile> images,
    String? userContext,
    String? sessionId,
    AIProvider? provider,
  }) async {
    try {
      // FIRST: Check if backend is available and preferred
      if (BackendConfig.useBackend && await BackendConfig.isBackendAvailable()) {
        print('🔮 AIService routing to BackendService');
        return await BackendService.identifyCrystal(
          images: images,
          userContext: userContext,
          sessionId: sessionId,
        );
      }
      
      print('🔮 AIService using direct AI provider (backend not available)');

      // Check usage limits
      if (!await UsageTracker.canIdentify()) {
        throw Exception(ApiConfig.quotaExceeded);
      }

      // Determine the best provider and model based on user's tier
      final identificationTier = await UsageTracker.getIdentificationTier();
      provider ??= _selectOptimalProvider(identificationTier);

      // Generate session ID if not provided
      sessionId ??= const Uuid().v4();

      // Check cache first
      final imageHash = await _generateImageHash(images);
      final cached = await CacheService.getCachedIdentification(imageHash);
      if (cached != null) {
        return cached;
      }

      // DEMO MODE or FALLBACK - If processing fails, use demo data
      try {
        // Check if we should use demo mode
        if (ApiConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE' &&
            ApiConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY_HERE') {
          return _getDemoIdentification(sessionId, images);
        }
      } catch (e) {
        print('🔮 Falling back to demo mode due to error: $e');
        return _getDemoIdentification(sessionId, images);
      }

      // Try to process images and get AI response
      try {
        // Prepare images
        final base64Images = await Future.wait(
          images.map((image) => _prepareImage(image)),
        );

        // Call the appropriate AI provider with tier information
        String response;
        switch (provider) {
          case AIProvider.gemini:
            response = await _callGemini(base64Images, userContext, tier: identificationTier);
            break;
          case AIProvider.openai:
            response = await _callOpenAI(base64Images, userContext, tier: identificationTier);
            break;
          case AIProvider.groq:
            response = await _callGroq(base64Images, userContext);
            break;
          default:
            throw Exception('Provider not implemented yet');
        }
        
        // Parse the response
        final identification = _parseResponse(
          response: response,
          sessionId: sessionId,
          images: images,
        );

        // Cache the result
        await CacheService.cacheIdentification(imageHash, identification);

        // Record usage - use premium tracking if using enhanced/premium models
        if (identificationTier != IdentificationTier.basic) {
          await UsageTracker.recordPremiumUsage();
        } else {
          await UsageTracker.recordUsage();
        }

        return identification;
        
      } catch (processingError) {
        print('🔮 AI processing failed, using demo mode: $processingError');
        // Fallback to demo identification if anything fails
        return _getDemoIdentification(sessionId, images);
      }

    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Google Gemini API call - Model selection based on user tier
  static Future<String> _callGemini(List<String> base64Images, String? userContext, {IdentificationTier? tier}) async {
    final apiKey = ApiConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      throw Exception('Please set your Gemini API key in api_config.dart\n'
                     'Get a FREE key at: https://makersuite.google.com/app/apikey');
    }

    // Select model based on tier
    String model;
    tier ??= await UsageTracker.getIdentificationTier();
    
    switch (tier) {
      case IdentificationTier.premium:
        model = 'gemini-1.5-pro'; // Best Gemini model for Pro users
        break;
      case IdentificationTier.enhanced:
        model = 'gemini-1.5-pro'; // Pro model for premium users
        break;
      case IdentificationTier.basic:
      default:
        model = 'gemini-2.0-flash-exp'; // Latest Gemini 2.0 Flash for free users
        break;
    }

    final url = '${_endpoints[AIProvider.gemini]}$model:generateContent?key=$apiKey';
    
    // Build Gemini-specific request format
    final parts = <Map<String, dynamic>>[];
    
    // Select appropriate prompt based on tier
    final prompt = (tier == IdentificationTier.premium) 
        ? _premiumSpiritualAdvisorPrompt 
        : _spiritualAdvisorPrompt;
    
    // Add the system prompt as text
    parts.add({
      'text': prompt + '\n\n' + 
              (userContext ?? 'Please identify this crystal and provide spiritual guidance.')
    });
    
    // Add images
    for (final imageData in base64Images) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': imageData,
        }
      });
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'parts': parts
        }],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE'
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception('Gemini API error: ${error['error']['message'] ?? response.statusCode}');
    }
  }

  /// OpenAI API call - Model selection based on user tier
  static Future<String> _callOpenAI(List<String> base64Images, String? userContext, {IdentificationTier? tier}) async {
    final apiKey = ApiConfig.openaiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_OPENAI_API_KEY') {
      throw Exception('Please set your OpenAI API key in api_config.dart');
    }

    // Select model based on tier
    String model;
    tier ??= await UsageTracker.getIdentificationTier();
    
    switch (tier) {
      case IdentificationTier.premium:
        model = 'gpt-4o'; // Best accuracy for pro users and new user bonus
        break;
      case IdentificationTier.enhanced:
        model = 'gpt-4o-mini'; // Good balance for premium users
        break;
      case IdentificationTier.basic:
      default:
        model = 'gpt-4o-mini'; // Cheaper option
        break;
    }

    final messages = <Map<String, dynamic>>[];
    
    // Select appropriate prompt based on tier
    final prompt = (tier == IdentificationTier.premium) 
        ? _premiumSpiritualAdvisorPrompt 
        : _spiritualAdvisorPrompt;
    
    // System prompt
    messages.add({
      'role': 'system',
      'content': prompt,
    });

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

    final response = await http.post(
      Uri.parse(_endpoints[AIProvider.openai]!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model, // Dynamic model based on user tier
        'messages': messages,
        'max_tokens': 2048,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }
  }

  /// Groq API call - Fast and cheap!
  static Future<String> _callGroq(List<String> base64Images, String? userContext) async {
    final apiKey = ApiConfig.groqApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GROQ_API_KEY') {
      throw Exception('Please set your Groq API key in api_config.dart\n'
                     'Get a FREE key at: https://console.groq.com/keys');
    }

    // Note: Groq doesn't support vision yet, so we'll use text description
    final messages = [
      {
        'role': 'system',
        'content': _spiritualAdvisorPrompt,
      },
      {
        'role': 'user',
        'content': userContext ?? 
          'Based on a crystal image (imagine a crystal with typical features), please provide spiritual guidance. Since you cannot see the image, provide general crystal wisdom.',
      },
    ];

    final response = await http.post(
      Uri.parse(_endpoints[AIProvider.groq]!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile', // Free and fast!
        'messages': messages,
        'max_tokens': 2048,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Groq API error: ${response.statusCode}');
    }
  }

  /// Selects the optimal AI provider based on user's identification tier
  static AIProvider _selectOptimalProvider(IdentificationTier tier) {
    switch (tier) {
      case IdentificationTier.premium:
        // Pro users and new user bonus get the best models
        // Prefer GPT-4o for highest accuracy, fallback to Claude 3.5
        if (ApiConfig.openaiApiKey != 'YOUR_OPENAI_API_KEY_HERE' && 
            ApiConfig.openaiApiKey.isNotEmpty) {
          return AIProvider.openai; // GPT-4o
        } else if (ApiConfig.claudeApiKey != 'YOUR_CLAUDE_API_KEY_HERE' && 
                   ApiConfig.claudeApiKey.isNotEmpty) {
          return AIProvider.claude; // Claude 3.5 Sonnet
        } else {
          return AIProvider.gemini; // Fallback to Gemini Pro
        }
        
      case IdentificationTier.enhanced:
        // Premium users get mid-tier models
        // Prefer Gemini Pro or GPT-4o-mini
        if (ApiConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' && 
            ApiConfig.geminiApiKey.isNotEmpty) {
          return AIProvider.gemini; // Will use Gemini Pro model
        } else if (ApiConfig.openaiApiKey != 'YOUR_OPENAI_API_KEY_HERE' && 
                   ApiConfig.openaiApiKey.isNotEmpty) {
          return AIProvider.openai; // Will use GPT-4o-mini
        } else {
          return AIProvider.gemini; // Fallback
        }
        
      case IdentificationTier.basic:
      default:
        // Free users get basic models (Gemini Flash)
        return AIProvider.gemini;
    }
  }

  // Helper methods (same as before)
  
  static Future<String> _prepareImage(PlatformFile imageFile) async {
    try {
      print('🔮 Processing image: ${imageFile.name}');
      
      // Ultra-simple approach for web compatibility
      // Just read and encode - no image processing that could cause namespace issues
      final bytes = await imageFile.readAsBytes();
      print('✅ Image bytes read: ${bytes.length}');
      
      // Direct base64 encoding - no external packages
      final base64String = base64Encode(bytes);
      print('✅ Image converted to base64: ${base64String.length} characters');
      
      return base64String;
      
    } catch (e) {
      print('❌ Image processing error: $e');
      // If even this simple approach fails, we'll use demo mode
      rethrow;
    }
  }

  static Future<String> _generateImageHash(List<PlatformFile> images) async {
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
    required List<PlatformFile> images,
  }) {
    // Extract crystal name and properties from response
    String crystalName = 'Unknown Crystal';
    double confidence = 0.7;
    
    // Simple extraction - look for crystal names
    final crystalNames = [
      'Amethyst', 'Clear Quartz', 'Rose Quartz', 'Citrine', 'Black Tourmaline',
      'Selenite', 'Labradorite', 'Fluorite', 'Pyrite', 'Malachite',
      'Lapis Lazuli', 'Amazonite', 'Carnelian', 'Obsidian', 'Jade',
      'Moonstone', 'Turquoise', 'Garnet', 'Aquamarine', 'Sodalite'
    ];
    
    for (final name in crystalNames) {
      if (response.contains(name)) {
        crystalName = name;
        break;
      }
    }
    
    // Parse confidence based on new mystical expressions
    if (response.toLowerCase().contains("spirits clearly reveal") || 
        response.toLowerCase().contains("spirits have shown")) {
      confidence = 0.9;
    } else if (response.toLowerCase().contains("energies suggest") || 
               response.toLowerCase().contains("vibrations indicate")) {
      confidence = 0.75;
    } else if (response.toLowerCase().contains("i sense") || 
               response.toLowerCase().contains("feels like")) {
      confidence = 0.55;
    } else if (response.toLowerCase().contains("message is unclear") || 
               response.toLowerCase().contains("guards its secrets")) {
      confidence = 0.3;
    }

    // Extract mystical message
    final lines = response.split('\n');
    final mysticalMessage = lines.firstWhere(
      (line) => line.contains('beloved seeker') || line.contains('energy') || line.contains('spiritual'),
      orElse: () => 'This crystal carries powerful energies for your spiritual journey.',
    );

    // Create crystal object
    final crystal = Crystal(
      id: const Uuid().v4(),
      name: crystalName,
      scientificName: '',
      group: 'Mineral',
      description: response,
      chakras: _extractChakras(response),
      elements: _extractElements(response),
      properties: {
        'healing': _extractHealingProperties(response),
        'energy': 'Balanced',
        'vibration': 'High',
      },
      careInstructions: 'Cleanse under moonlight, charge with intention.',
    );

    return CrystalIdentification(
      sessionId: sessionId,
      crystal: crystal,
      confidence: confidence,
      mysticalMessage: mysticalMessage,
      fullResponse: response,
      timestamp: DateTime.now(),
    );
  }

  static List<String> _extractChakras(String response) {
    final chakras = <String>[];
    final chakraNames = ['Root', 'Sacral', 'Solar Plexus', 'Heart', 'Throat', 'Third Eye', 'Crown'];
    
    for (final chakra in chakraNames) {
      if (response.contains(chakra)) {
        chakras.add(chakra);
      }
    }
    
    return chakras.isEmpty ? ['Heart'] : chakras;
  }

  static List<String> _extractElements(String response) {
    final elements = <String>[];
    final elementNames = ['Earth', 'Water', 'Fire', 'Air', 'Spirit'];
    
    for (final element in elementNames) {
      if (response.toLowerCase().contains(element.toLowerCase())) {
        elements.add(element);
      }
    }
    
    return elements.isEmpty ? ['Earth'] : elements;
  }

  static List<String> _extractHealingProperties(String response) {
    final properties = <String>[];
    
    if (response.toLowerCase().contains('healing')) {
      properties.add('Physical healing');
    }
    if (response.toLowerCase().contains('emotional')) {
      properties.add('Emotional balance');
    }
    if (response.toLowerCase().contains('protection')) {
      properties.add('Protective shield');
    }
    if (response.toLowerCase().contains('meditation')) {
      properties.add('Enhanced meditation');
    }
    
    return properties.isEmpty ? ['General wellbeing'] : properties;
  }

  static Exception _handleError(dynamic error) {
    print('🔮 Handling error: $error');
    
    if (error.toString().contains('SocketException')) {
      return Exception('Network error - please check your connection');
    } else if (error.toString().contains('401')) {
      return Exception('Invalid API key - please check your settings');
    } else if (error.toString().contains('quota')) {
      return Exception('API quota exceeded - try again later');
    } else if (error.toString().contains('Failed to process image')) {
      return Exception('Image processing failed - try a different image format (JPG/PNG)');
    } else if (error.toString().contains('Cannot read image file')) {
      return Exception('Cannot read image file - please try uploading again');
    } else if (error.toString().contains('Invalid image format')) {
      return Exception('Invalid image format - please use JPG or PNG files');
    } else if (error.toString().contains('UnsupportedError')) {
      return Exception('Image operation not supported - try a different image');
    } else {
      return Exception('AI service error: ${error.toString()}');
    }
  }

  /// Demo mode identification for testing without API key
  static CrystalIdentification _getDemoIdentification(String sessionId, List<PlatformFile> images) {
    final demoResponses = [
      {
        'name': 'Amethyst',
        'confidence': 0.9,
        'response': '''Ah, beloved seeker, you have discovered a magnificent Amethyst cluster!

I'm quite certain this is Amethyst, a variety of quartz with stunning purple coloration. The violet hues I observe in your crystal range from light lavender to deep purple, created by iron impurities and natural irradiation within the Earth.

**Key Identifying Features:**
- Purple to violet coloration
- Hexagonal crystal system visible in the terminations
- Vitreous (glass-like) luster
- Translucent to transparent clarity
- Natural crystal points forming a cluster

**Scientific Properties:**
- Hardness: 7 on the Mohs scale
- Crystal System: Hexagonal
- Chemical Composition: SiO₂ (Silicon Dioxide)
- Formation: Typically in geodes and volcanic rocks

**Metaphysical Properties:**
- Crown and Third Eye chakra activation
- Enhanced intuition and spiritual awareness
- Protection from negative energies
- Promotes clarity of mind and emotional balance
- Aids in meditation and connection to higher realms

**Chakra Associations:**
The purple rays of Amethyst resonate powerfully with your Crown Chakra, opening pathways to divine wisdom, while also activating your Third Eye for enhanced intuition and psychic abilities.

**Personalized Spiritual Guidance:**
This Amethyst has called to you during a time of spiritual awakening. Its presence suggests you are ready to deepen your intuitive abilities and connect more fully with your higher self. Place this crystal on your nightstand to enhance dream recall and spiritual insights during sleep.

**Care Instructions:**
Cleanse your Amethyst monthly under cool running water, then charge it overnight in moonlight, especially during the full moon. Avoid prolonged sunlight exposure which may fade its beautiful purple color. You may also cleanse it with sage smoke or by placing it on a selenite charging plate.

May this sacred purple guardian illuminate your path with divine wisdom and protect you on your spiritual journey, dear one. Trust in its ancient wisdom to guide you toward your highest good. 💜✨''',
        'chakras': ['Crown', 'Third Eye'],
        'elements': ['Air', 'Water'],
        'healing': ['Calms the mind', 'Enhances intuition', 'Promotes restful sleep', 'Relieves stress'],
      },
      {
        'name': 'Clear Quartz',
        'confidence': 0.85,
        'response': '''Ah, beloved seeker, you hold in your hands the master healer - Clear Quartz!

This appears to be Clear Quartz, the most versatile and programmable crystal in the mineral kingdom. Its pristine clarity speaks of its pure vibrational frequency and ability to amplify energy and intention.

**Key Identifying Features:**
- Crystal clear transparency
- Hexagonal crystal structure
- Glass-like luster
- Natural termination points
- Possible rainbow inclusions or phantoms

**Scientific Properties:**
- Hardness: 7 on the Mohs scale
- Crystal System: Hexagonal
- Chemical Composition: SiO₂ (Silicon Dioxide)
- Piezoelectric properties

**Metaphysical Properties:**
- Amplifies energy and intention
- Cleanses and balances all chakras
- Enhances psychic abilities
- Stores, releases, and regulates energy
- Aids in manifestation work

**Chakra Associations:**
Clear Quartz is unique in its ability to harmonize with all seven chakras, though it resonates particularly strongly with the Crown Chakra, creating a clear channel for divine light to flow through your entire energy system.

**Personalized Spiritual Guidance:**
This crystal has found its way to you as a spiritual amplifier. Whatever intentions you set, this Clear Quartz will magnify them tenfold. Program it by holding it to your heart, stating your intention clearly three times, and visualizing white light sealing your wish within the crystal.

**Care Instructions:**
Clear Quartz loves to be cleansed frequently due to its amplifying nature. Cleanse weekly under running water, in moonlight, or with sound vibrations. Charge in sunlight for short periods or on a bed of hematite. Regular cleansing keeps its channel clear for optimal energy work.

This crystal companion will serve as your spiritual swiss army knife, beloved one. May its pure light illuminate all shadows and amplify only the highest good in your life. ✨🔮''',
        'chakras': ['All Chakras', 'Crown'],
        'elements': ['All Elements'],
        'healing': ['Master healer', 'Boosts immune system', 'Enhances energy flow', 'Clears energy blockages'],
      },
      {
        'name': 'Rose Quartz',
        'confidence': 0.88,
        'response': '''Ah, beloved seeker, your heart has drawn to you the stone of unconditional love - Rose Quartz!

I believe this is Rose Quartz, the gentle pink crystal of the heart. Its soft, rosy hues emanate the frequency of love, compassion, and emotional healing that your soul seeks at this time.

**Key Identifying Features:**
- Soft pink to rose coloration
- Translucent quality
- Massive formation (not typically found in points)
- Smooth, almost waxy luster
- Gentle, soothing energy signature

**Scientific Properties:**
- Hardness: 7 on the Mohs scale
- Crystal System: Hexagonal
- Color from: Titanium, iron, or manganese
- Often found in massive formations

**Metaphysical Properties:**
- Unconditional love and self-love
- Emotional healing and release
- Attracts love and harmonious relationships
- Soothes grief and heartache
- Promotes inner peace and self-acceptance

**Chakra Associations:**
Rose Quartz resonates deeply with your Heart Chakra, gently opening this energy center to give and receive love more freely. It creates a soft pink light of healing around your entire emotional body.

**Personalized Spiritual Guidance:**
This loving crystal has appeared in your life to help you cultivate deeper self-love and compassion. Place it over your heart during meditation and repeat: "I am worthy of love. I am love." Sleep with it under your pillow to receive its gentle healing throughout the night.

**Care Instructions:**
Cleanse your Rose Quartz in lukewarm water with a drop of mild soap, as it appreciates gentle care. Charge it in moonlight or with your loving intention. Avoid harsh sunlight which may fade its delicate pink color. You can also cleanse it by burying it in rose petals overnight.

May this tender pink guardian open your heart to infinite love, starting with the love you show yourself, precious soul. Trust its gentle wisdom to heal old wounds and attract new blessings. 💗🌹''',
        'chakras': ['Heart', 'Higher Heart'],
        'elements': ['Water', 'Earth'],
        'healing': ['Heals emotional wounds', 'Promotes self-love', 'Eases anxiety', 'Supports heart health'],
      }
    ];

    // Randomly select a demo crystal
    final demo = demoResponses[DateTime.now().millisecond % demoResponses.length];
    
    // Add some randomness to confidence
    final confidence = (demo['confidence'] as double) + 
        (DateTime.now().millisecond % 10 - 5) / 100;

    final crystal = Crystal(
      id: const Uuid().v4(),
      name: demo['name'] as String,
      scientificName: 'Demo Crystal',
      group: 'Quartz Family',
      description: demo['response'] as String,
      chakras: demo['chakras'] as List<String>,
      elements: demo['elements'] as List<String>,
      properties: {
        'healing': demo['healing'] as List<String>,
        'energy': 'High Vibration',
        'vibration': 'Harmonious',
      },
      careInstructions: 'Cleanse under moonlight, charge with intention.',
    );

    return CrystalIdentification(
      sessionId: sessionId,
      crystal: crystal,
      confidence: confidence.clamp(0.0, 1.0),
      mysticalMessage: 'This crystal has chosen you for a reason. Trust in its wisdom and allow its energy to guide your spiritual journey. 🔮✨',
      fullResponse: demo['response'] as String,
      timestamp: DateTime.now(),
    );
  }
}