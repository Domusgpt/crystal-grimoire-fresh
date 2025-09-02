import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../services/collection_service_v2.dart';
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
    super.dispose();
  }

  void _selectChakra(String chakra) {
    setState(() {
      selectedChakra = chakra;
      _updateRecommendedCrystals(chakra);
    });
  }

  void _updateRecommendedCrystals(String chakra) {
    final collectionService = context.read<CollectionServiceV2>();
    final chakraCrystals = chakraData[chakra]!['crystals'] as List<String>;
    
    // Filter to show only crystals the user owns
    recommendedCrystals = collectionService.collection
        .where((entry) => chakraCrystals.contains(entry.crystal.name))
        .map((entry) => entry.crystal.name)
        .toList();
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
                onTap: _startHealingSession,
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
            final isOwned = recommendedCrystals.contains(crystal);
            
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

  void _startHealingSession() {
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