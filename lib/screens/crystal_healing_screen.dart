import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';
import '../services/app_state.dart';
import 'package:provider/provider.dart';

class CrystalHealingScreen extends StatefulWidget {
  const CrystalHealingScreen({Key? key}) : super(key: key);

  @override
  State<CrystalHealingScreen> createState() => _CrystalHealingScreenState();
}

class _CrystalHealingScreenState extends State<CrystalHealingScreen> 
    with TickerProviderStateMixin {
  late AnimationController _chakraAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _chakraAnimation;
  late Animation<double> _pulseAnimation;
  
  String? selectedChakra;
  List<String> recommendedCrystals = [];
  List<String> _suggestedCrystals = [];
  bool _isLoadingLayout = false;
  String? _layoutError;
  Map<String, dynamic>? _healingLayout;
  Map<String, dynamic>? _compatibility;
  final TextEditingController _intentionController = TextEditingController();

  final Map<String, Map<String, dynamic>> chakraData = {
    'Crown': {
      'color': const Color(0xFF9B59B6),
      'location': 'Top of head',
      'element': 'Thought',
      'crystals': ['Clear Quartz', 'Amethyst', 'Selenite', 'Lepidolite'],
      'affirmation': 'I am connected to divine wisdom',
      'frequency': '963 Hz',
      'position': 0.1,
    },
    'Third Eye': {
      'color': const Color(0xFF3498DB),
      'location': 'Between eyebrows',
      'element': 'Light',
      'crystals': ['Lapis Lazuli', 'Sodalite', 'Fluorite', 'Labradorite'],
      'affirmation': 'I trust my intuition',
      'frequency': '852 Hz',
      'position': 0.2,
    },
    'Throat': {
      'color': const Color(0xFF5DADE2),
      'location': 'Throat',
      'element': 'Sound',
      'crystals': ['Blue Lace Agate', 'Aquamarine', 'Turquoise', 'Celestite'],
      'affirmation': 'I speak my truth with clarity',
      'frequency': '741 Hz',
      'position': 0.35,
    },
    'Heart': {
      'color': const Color(0xFF27AE60),
      'location': 'Center of chest',
      'element': 'Air',
      'crystals': ['Rose Quartz', 'Green Aventurine', 'Rhodonite', 'Malachite'],
      'affirmation': 'I give and receive love freely',
      'frequency': '639 Hz',
      'position': 0.5,
    },
    'Solar Plexus': {
      'color': const Color(0xFFF39C12),
      'location': 'Above navel',
      'element': 'Fire',
      'crystals': ['Citrine', 'Yellow Jasper', 'Tiger Eye', 'Pyrite'],
      'affirmation': 'I am confident and empowered',
      'frequency': '528 Hz',
      'position': 0.65,
    },
    'Sacral': {
      'color': const Color(0xFFE67E22),
      'location': 'Below navel',
      'element': 'Water',
      'crystals': ['Carnelian', 'Orange Calcite', 'Sunstone', 'Moonstone'],
      'affirmation': 'I embrace pleasure and creativity',
      'frequency': '417 Hz',
      'position': 0.8,
    },
    'Root': {
      'color': const Color(0xFFE74C3C),
      'location': 'Base of spine',
      'element': 'Earth',
      'crystals': ['Red Jasper', 'Black Tourmaline', 'Hematite', 'Smoky Quartz'],
      'affirmation': 'I am grounded and secure',
      'frequency': '396 Hz',
      'position': 0.9,
    },
  };

  @override
  void initState() {
    super.initState();
    _chakraAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _chakraAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _chakraAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _intentionController.text = 'Holistic balance';
  }

  @override
  void dispose() {
    _chakraAnimationController.dispose();
    _pulseController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  void _selectChakra(String chakra) {
    setState(() {
      selectedChakra = chakra;
      _layoutError = null;
    });
    _updateOwnedRecommendations(chakra);
    _loadHealingPlan(chakra);
  }

  void _updateOwnedRecommendations(String chakra) {
    final collectionService = context.read<CollectionServiceV2>();
    final chakraCrystals = chakraData[chakra]!['crystals'] as List<String>;
    final owned = collectionService.collection
        .map((entry) => entry.crystal.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet();

    setState(() {
      recommendedCrystals = chakraCrystals
          .where((crystal) => owned.contains(crystal))
          .toList();
    });
  }

  Future<void> _loadHealingPlan(String chakra) async {
    final collectionService = context.read<CollectionServiceV2>();
    final crystalService = context.read<CrystalService>();
    final available = collectionService.collection
        .map((entry) => entry.crystal.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _isLoadingLayout = true;
      _healingLayout = null;
      _compatibility = null;
      _suggestedCrystals = [];
    });

    try {
      final layoutResult = await crystalService.generateHealingLayout(
        availableCrystals: available,
        targetChakras: [chakra],
        intention: _intentionController.text.trim().isEmpty
            ? null
            : _intentionController.text.trim(),
      );

      Map<String, dynamic>? layout;
      List<Map<String, dynamic>> placements = [];
      if (layoutResult != null) {
        layout = Map<String, dynamic>.from(layoutResult['layout'] as Map? ?? {});
        placements = List<Map<String, dynamic>>.from(
          (layout['placements'] as List? ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map)),
        );
        final placementCrystals = placements
            .map((placement) => placement['crystal']?.toString())
            .whereType<String>()
            .toList();
        final supplemental = List<String>.from(
          layoutResult['suggestedCrystals'] ?? const <String>[],
        );

        final suggestions = {
          ...placementCrystals,
          ...supplemental,
        }.where((name) => name.trim().isNotEmpty).toList();

        final ownedSet = available.map((name) => name.toLowerCase()).toSet();
        final intersection = suggestions
            .where((name) => ownedSet.contains(name.toLowerCase()))
            .toList();

        Map<String, dynamic>? compatibility;
        if (placementCrystals.isNotEmpty) {
          compatibility = await crystalService.checkCompatibility(
            crystalNames: placementCrystals,
            purpose: layout['intention']?.toString(),
          );
        }

        setState(() {
          _healingLayout = layout;
          _compatibility = compatibility;
          _suggestedCrystals = suggestions;
          recommendedCrystals = intersection;
          _isLoadingLayout = false;
          _layoutError = null;
        });
        return;
      }

      setState(() {
        _healingLayout = layout;
        _compatibility = null;
        _suggestedCrystals = const [];
        recommendedCrystals = [];
        _isLoadingLayout = false;
        _layoutError = 'No layout available yet. Try refreshing after adding crystals to your collection.';
      });
    } catch (error) {
      debugPrint('Healing layout generation failed: $error');
      setState(() {
        _healingLayout = null;
        _compatibility = null;
        _suggestedCrystals = const [];
        _isLoadingLayout = false;
        _layoutError = 'Unable to generate a healing layout right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Crystal Healing',
          style: GoogleFonts.cinzel(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Mystical background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0015),
                  Color(0xFF1A0B2E),
                  Color(0xFF2D1B69),
                ],
              ),
            ),
          ),
          
          // Energy particles
          AnimatedBuilder(
            animation: _chakraAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: EnergyParticlesPainter(
                  animationValue: _chakraAnimation.value,
                ),
              );
            },
          ),
          
          SafeArea(
            child: selectedChakra == null
                ? _buildChakraSelector()
                : _buildHealingSession(),
          ),
        ],
      ),
    );
  }

  Widget _buildChakraSelector() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(
          'Select a Chakra to Balance',
          style: GoogleFonts.cinzel(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Human silhouette
              Container(
                width: 200,
                height: 400,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              
              // Chakra points
              ...chakraData.entries.map((entry) {
                final chakra = entry.key;
                final data = entry.value;
                final position = data['position'] as double;
                
                return Positioned(
                  top: position * 400,
                  child: GestureDetector(
                    onTap: () => _selectChakra(chakra),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: data['color'] as Color,
                              boxShadow: [
                                BoxShadow(
                                  color: (data['color'] as Color).withOpacity(0.6),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.brightness_1,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        
        // Chakra legend
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: chakraData.length,
            itemBuilder: (context, index) {
              final chakra = chakraData.keys.elementAt(index);
              final color = chakraData[chakra]!['color'] as Color;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chakra,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHealingSession() {
    final data = chakraData[selectedChakra]!;
    final chakraCrystals = data['crystals'] as List<String>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  selectedChakra = null;
                });
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              label: Text(
                'Change Chakra',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ),
          ),
          
          // Chakra visualization
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data['color'] as Color,
                    boxShadow: [
                      BoxShadow(
                        color: (data['color'] as Color).withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          selectedChakra!,
                          style: GoogleFonts.cinzel(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          data['element'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Chakra info card
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Location',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          data['location'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Frequency',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          data['frequency'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (data['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (data['color'] as Color).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_quote,
                            color: data['color'] as Color,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data['affirmation'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          _buildIntentionInput(data['color'] as Color),

          const SizedBox(height: 24),

          _buildLayoutInsights(),

          const SizedBox(height: 24),

          // Recommended crystals from collection
          _buildRecommendedCrystals(chakraCrystals),

          const SizedBox(height: 24),

          _buildCompatibilityInsights(),

          const SizedBox(height: 24),

          // Start healing session button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  data['color'] as Color,
                  (data['color'] as Color).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (data['color'] as Color).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _startHealingSession(),
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Start Healing Session',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentionInput(Color accentColor) {
    return TextField(
      controller: _intentionController,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Healing Intention',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accentColor.withOpacity(0.6)),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.autorenew, color: Colors.white70),
          tooltip: 'Refresh layout with this intention',
          onPressed: selectedChakra == null
              ? null
              : () => _loadHealingPlan(selectedChakra!),
        ),
      ),
    );
  }

  Widget _buildLayoutInsights() {
    if (_isLoadingLayout) {
      return _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: const [
              CircularProgressIndicator(color: Colors.white70),
              SizedBox(height: 12),
              Text(
                'Aligning crystals with your chakra...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_layoutError != null) {
      return _buildGlassCard(
        child: Text(
          _layoutError!,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    if (_healingLayout == null) {
      return _buildGlassCard(
        child: Text(
          'Select a chakra to receive a guided placement layout.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    final layout = _healingLayout!;
    final placements = List<Map<String, dynamic>>.from(
      (layout['placements'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map)),
    );
    final breathwork = Map<String, dynamic>.from(layout['breathwork'] as Map? ?? {});
    final integration = List<String>.from(layout['integration'] ?? const <String>[]);
    final affirmation = layout['affirmation']?.toString();
    final duration = layout['durationMinutes'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.self_improvement, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'Crystal Placements',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (duration != null)
                    Text(
                      '${duration.toString()} min',
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (placements.isEmpty)
                Text(
                  'No placements generated yet. Try refreshing with a different intention.',
                  style: GoogleFonts.poppins(color: Colors.white70),
                )
              else
                Column(
                  children: placements.map((placement) {
                    final focus = List<String>.from(placement['focus'] ?? const <String>[]);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withOpacity(0.07),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            placement['crystal']?.toString() ?? 'Crystal',
                            style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Place on ${placement['chakra']}',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            placement['instructions']?.toString() ?? '',
                            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), height: 1.4),
                          ),
                          if (focus.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Focus: ${focus.join(' • ')}',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        if (breathwork.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.air, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        breathwork['technique']?.toString() ?? 'Breathwork',
                        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        breathwork['description']?.toString() ?? '',
                        style: GoogleFonts.poppins(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (integration.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Integration',
                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                for (final step in integration)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.white60, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step,
                            style: GoogleFonts.poppins(color: Colors.white70, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (affirmation != null && affirmation.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.self_improvement, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    affirmation,
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompatibilityInsights() {
    if (_compatibility == null) {
      return const SizedBox.shrink();
    }

    final score = _compatibility?['score'];
    final dominantChakra = _compatibility?['dominantChakra'];
    final dominantElement = _compatibility?['dominantElement'];
    final synergies = List<String>.from(_compatibility?['synergies'] ?? const <String>[]);
    final cautions = List<String>.from(_compatibility?['cautions'] ?? const <String>[]);

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.balance, color: Colors.white70),
              const SizedBox(width: 12),
              Text(
                'Crystal Compatibility',
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Score $score',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (dominantChakra != null || dominantElement != null)
            Row(
              children: [
                if (dominantChakra != null)
                  _buildInfoChip('Dominant Chakra', dominantChakra.toString()),
                if (dominantChakra != null && dominantElement != null)
                  const SizedBox(width: 12),
                if (dominantElement != null)
                  _buildInfoChip('Dominant Element', dominantElement.toString()),
              ],
            ),
          if (synergies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Synergies', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            for (final item in synergies)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.poppins(color: Colors.white70, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (cautions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Cautions', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            for (final item in cautions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.poppins(color: Colors.white70, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildRecommendedCrystals(List<String> chakraCrystals) {
    final displayList = _suggestedCrystals.isNotEmpty
        ? _suggestedCrystals
        : chakraCrystals;
    final unique = <String>{};
    final normalizedSuggestions = displayList
        .where((name) => unique.add(name.toLowerCase()))
        .toList();
    final ownedSet = recommendedCrystals
        .map((name) => name.toLowerCase())
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Healing Crystals',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: normalizedSuggestions.length,
          itemBuilder: (context, index) {
            final crystal = normalizedSuggestions[index];
            final isOwned = ownedSet.contains(crystal.toLowerCase());

            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: isOwned 
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.diamond,
                        color: isOwned 
                            ? const Color(0xFF10B981) 
                            : Colors.white60,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        crystal,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isOwned) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'In Collection',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (recommendedCrystals.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              'Add some $selectedChakra chakra crystals to your collection for enhanced healing!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Future<void> _startHealingSession() async {
    try {
      await context.read<AppState>().incrementUsage('healing_session');
    } catch (_) {
      // Usage tracking failures should not block the UI flow.
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (chakraData[selectedChakra]!['color'] as Color),
                boxShadow: [
                  BoxShadow(
                    color: (chakraData[selectedChakra]!['color'] as Color).withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.healing,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Healing Session Started',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Place your ${recommendedCrystals.isNotEmpty ? recommendedCrystals.first : "healing crystal"} on your $selectedChakra area and breathe deeply.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Complete',
              style: GoogleFonts.poppins(
                color: chakraData[selectedChakra]!['color'] as Color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EnergyParticlesPainter extends CustomPainter {
  final double animationValue;

  EnergyParticlesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 30; i++) {
      final x = (i * 137.5 + animationValue * size.width) % size.width;
      final y = (math.sin(i + animationValue * math.pi * 2) * 100) + 
                size.height / 2 + (i * 23.0 % size.height / 2);
      final opacity = (math.sin(animationValue * math.pi * 2 + i) + 1) / 2;
      final radius = 2 + math.sin(i + animationValue * math.pi) * 2;
      
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}