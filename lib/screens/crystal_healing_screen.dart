import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';
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

  final TextEditingController _intentionController = TextEditingController();
  final Set<String> _targetChakras = {};
  Map<String, dynamic>? _layoutResult;
  List<Map<String, dynamic>> _placements = [];
  List<String> _suggestedCrystals = [];
  bool _isGenerating = false;
  String? _layoutError;
  Set<String> _ownedCrystalNames = {};
  
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
  }

  @override
  void dispose() {
    _chakraAnimationController.dispose();
    _pulseController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  void _selectChakra(String chakra) {
    final collectionService = context.read<CollectionServiceV2>();
    final owned = collectionService.collection
        .map((entry) => entry.crystal.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    setState(() {
      selectedChakra = chakra;
      if (_targetChakras.isEmpty) {
        _targetChakras.add(chakra);
      }
      _ownedCrystalNames = owned.map((name) => name.toLowerCase()).toSet();
      _updateRecommendedCrystals(chakra, owned);
    });
  }

  void _toggleChakraTarget(String chakra) {
    setState(() {
      if (_targetChakras.contains(chakra)) {
        _targetChakras.remove(chakra);
      } else {
        _targetChakras.add(chakra);
      }
      if (_targetChakras.isEmpty && selectedChakra != null) {
        _targetChakras.add(selectedChakra!);
      }
    });
  }

  Future<void> _generateLayout() async {
    final collectionService = context.read<CollectionServiceV2>();
    final crystalService = context.read<CrystalService>();

    final availableCrystals = collectionService.collection
        .map((entry) => entry.crystal.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (availableCrystals.isEmpty) {
      setState(() {
        _layoutError = 'Add crystals to your collection to generate a layout.';
        _layoutResult = null;
        _placements = [];
        _suggestedCrystals = [];
      });
      return;
    }

    final targetChakras = _targetChakras.isNotEmpty
        ? _targetChakras.toList()
        : (selectedChakra != null ? [selectedChakra!] : ['Full Alignment']);

    final normalizedOwned = availableCrystals
        .map((name) => name.toLowerCase())
        .toSet();

    setState(() {
      _isGenerating = true;
      _layoutError = null;
      _ownedCrystalNames = normalizedOwned;
    });

    try {
      final result = await crystalService.generateHealingLayout(
        availableCrystals: availableCrystals.toList(),
        targetChakras: targetChakras,
        intention: _intentionController.text.trim().isEmpty
            ? null
            : _intentionController.text.trim(),
      );

      if (!mounted) return;

      if (result == null || result['layout'] == null) {
        throw Exception('No layout returned');
      }

      final layout = Map<String, dynamic>.from(result['layout'] as Map);
      final placementData = (layout['placements'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          <Map<String, dynamic>>[];
      final suggested = (result['suggestedCrystals'] as List?)
              ?.whereType<String>()
              .toList() ??
          <String>[];

      setState(() {
        _layoutResult = layout;
        _placements = placementData;
        _suggestedCrystals = suggested;
        _layoutError = null;
      });
    } catch (error, stack) {
      debugPrint('generateHealingLayout failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _layoutError = 'Unable to generate a layout right now. Try again later.';
        _layoutResult = null;
        _placements = [];
        _suggestedCrystals = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _updateRecommendedCrystals(String chakra,
      [List<String>? ownedNamesOverride]) {
    final collectionService = context.read<CollectionServiceV2>();
    final chakraCrystals = chakraData[chakra]!['crystals'] as List<String>;

    final ownedNames = ownedNamesOverride ??
        collectionService.collection
            .map((entry) => entry.crystal.name.trim())
            .where((name) => name.isNotEmpty)
            .toList();

    recommendedCrystals = collectionService.collection
        .where((entry) => chakraCrystals.contains(entry.crystal.name))
        .map((entry) => entry.crystal.name)
        .toList();

    if (recommendedCrystals.isEmpty) {
      final lowerLookup = chakraCrystals
          .map((crystal) => crystal.toLowerCase())
          .toSet();
      recommendedCrystals = ownedNames
          .where((name) => lowerLookup.contains(name.toLowerCase()))
          .toList();
    }

    _ownedCrystalNames = ownedNames.map((name) => name.toLowerCase()).toSet();
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
          
          // Recommended crystals from collection
          _buildRecommendedCrystals(chakraCrystals),

          const SizedBox(height: 24),

          _buildLayoutControls(data),

          const SizedBox(height: 24),

          _buildLayoutResults(),
        ],
      ),
    );
  }

  Widget _buildRecommendedCrystals(List<String> chakraCrystals) {
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
          itemCount: chakraCrystals.length,
          itemBuilder: (context, index) {
            final crystal = chakraCrystals[index];
            final isOwned =
                _ownedCrystalNames.contains(crystal.toLowerCase());
            final accentColor =
                isOwned ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

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
                        isOwned
                            ? Colors.white.withOpacity(0.12)
                            : Colors.white.withOpacity(0.05),
                        isOwned
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.02),
                      ],
                    ),
                    border: Border.all(
                      color: accentColor.withOpacity(isOwned ? 0.5 : 0.4),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.diamond,
                        color: isOwned ? accentColor : Colors.white60,
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
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isOwned ? 'In Collection' : 'Not in collection',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  Widget _buildLayoutControls(Map<String, dynamic> chakraInfo) {
    final color = chakraInfo['color'] as Color? ?? const Color(0xFF8B5CF6);
    final activeTargets = _targetChakras.isNotEmpty
        ? _targetChakras
        : {if (selectedChakra != null) selectedChakra!};
    final lackingTargets = activeTargets.where((chakra) {
      final crystals = chakraData[chakra]?['crystals'] as List<String>?;
      if (crystals == null || crystals.isEmpty) {
        return false;
      }
      return !crystals.any(
        (name) => _ownedCrystalNames.contains(name.toLowerCase()),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Healing Intention',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (lackingTargets.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCoverageWarning(lackingTargets),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _intentionController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Grounding anxiety before sleep',
            hintStyle: GoogleFonts.poppins(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color.withOpacity(0.8)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _generateLayout(),
        ),
        const SizedBox(height: 20),
        Text(
          'Target Chakras',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chakraData.keys.map((chakra) {
            final isSelected = _targetChakras.contains(chakra);
            final chakraColor = chakraData[chakra]!['color'] as Color;
            return FilterChip(
              selected: isSelected,
              onSelected: (_) => _toggleChakraTarget(chakra),
              label: Text(
                chakra,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              showCheckmark: false,
              selectedColor: chakraColor.withOpacity(0.35),
              backgroundColor: Colors.white.withOpacity(0.05),
              side: BorderSide(
                color: isSelected
                    ? chakraColor.withOpacity(0.6)
                    : Colors.white24,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateLayout,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.85),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _isGenerating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isGenerating
                  ? 'Generating layout...'
                  : 'Generate Healing Layout',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_layoutError != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.4),
              ),
            ),
            child: Text(
              _layoutError!,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLayoutResults() {
    if (_layoutResult == null &&
        _placements.isEmpty &&
        _suggestedCrystals.isEmpty) {
      return const SizedBox.shrink();
    }

    final layout = _layoutResult;
    final intention = layout?['intention']?.toString();
    final duration = layout?['durationMinutes'];
    final affirmation = layout?['affirmation']?.toString();
    final breathwork = layout?['breathwork'] is Map
        ? Map<String, dynamic>.from(layout!['breathwork'] as Map)
        : null;
    final integration = (layout?['integration'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];

    final sections = <Widget>[];

    if (_placements.isNotEmpty) {
      sections.add(
        _buildGlassSection(
          title: 'Crystal Placements',
          icon: Icons.healing,
          children: [
            if (intention != null && intention.isNotEmpty)
              _buildLayoutMetaRow('Intention', intention),
            if (duration is num)
              _buildLayoutMetaRow(
                'Estimated duration',
                '${duration.round()} minutes',
              ),
            if ((intention?.isNotEmpty ?? false) || duration is num)
              const SizedBox(height: 12),
            ..._placements
                .asMap()
                .entries
                .map((entry) => _buildPlacementTile(entry.key, entry.value)),
          ],
        ),
      );
    }

    if (_suggestedCrystals.isNotEmpty) {
      sections.add(
        _buildGlassSection(
          title: 'Additional Allies',
          icon: Icons.local_florist,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedCrystals.map((name) {
                final isOwned =
                    _ownedCrystalNames.contains(name.toLowerCase());
                final chipColor = isOwned
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFF59E0B).withOpacity(0.18);
                final borderColor =
                    isOwned ? Colors.white24 : const Color(0xFFF59E0B);
                final icon =
                    isOwned ? Icons.check_circle : Icons.add_circle_outline;

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isOwned
                            ? Colors.white70
                            : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    if (breathwork != null) {
      sections.add(
        _buildGlassSection(
          title: 'Breathwork',
          icon: Icons.self_improvement,
          children: [
            if (breathwork['technique'] != null)
              Text(
                breathwork['technique'].toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (breathwork['description'] != null) ...[
              const SizedBox(height: 6),
              Text(
                breathwork['description'].toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (integration.isNotEmpty) {
      sections.add(
        _buildGlassSection(
          title: 'Integration',
          icon: Icons.bubble_chart,
          children: integration
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.north_east,
                          color: Colors.white60, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    if (affirmation != null && affirmation.isNotEmpty) {
      sections.add(
        _buildGlassSection(
          title: 'Affirmation',
          icon: Icons.auto_awesome,
          children: [
            Text(
              affirmation,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Blueprint',
          style: GoogleFonts.cinzel(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: section,
            )),
      ],
    );
  }

  Widget _buildGlassSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white70),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: GoogleFonts.cinzel(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementTile(int index, Map<String, dynamic> placement) {
    final chakra = placement['chakra']?.toString() ?? 'Chakra';
    final crystal = placement['crystal']?.toString() ?? 'Crystal';
    final instructions = placement['instructions']?.toString() ?? '';
    final focus = (placement['focus'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final color = chakraData[chakra]?['color'] as Color? ?? Colors.white70;
    final isOwned = _ownedCrystalNames.contains(crystal.toLowerCase());
    final accentColor = isOwned ? color : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(isOwned ? 0.35 : 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. $chakra Alignment',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            crystal,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isOwned) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Not in your collection yet',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFF59E0B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (focus.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              focus.join(' • '),
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              instructions,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverageWarning(List<String> lackingTargets) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You don\'t have crystals aligned with ${lackingTargets.join(', ')} yet. Add allies for those chakras to unlock the full layout guidance.',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
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
