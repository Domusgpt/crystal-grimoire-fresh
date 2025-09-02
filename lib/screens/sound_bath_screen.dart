import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;

class SoundBathScreen extends StatefulWidget {
  const SoundBathScreen({Key? key}) : super(key: key);

  @override
  State<SoundBathScreen> createState() => _SoundBathScreenState();
}

class _SoundBathScreenState extends State<SoundBathScreen> 
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _breathingController;
  late AnimationController _glowController;
  late Animation<double> _waveAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  
  bool isPlaying = false;
  String selectedSound = 'Crystal Bowl';
  int selectedDuration = 10; // minutes
  
  final Map<String, Map<String, dynamic>> soundData = {
    'Crystal Bowl': {
      'frequency': '432 Hz',
      'description': 'Pure crystal vibrations for deep healing',
      'color': const Color(0xFF9333EA),
      'icon': Icons.album,
    },
    'Tibetan Bowl': {
      'frequency': '528 Hz',
      'description': 'Ancient healing frequencies',
      'color': const Color(0xFFD97706),
      'icon': Icons.circle,
    },
    'Ocean Waves': {
      'frequency': 'Natural',
      'description': 'Calming rhythm of the sea',
      'color': const Color(0xFF0EA5E9),
      'icon': Icons.waves,
    },
    'Rain Forest': {
      'frequency': 'Natural',
      'description': 'Immersive nature sounds',
      'color': const Color(0xFF10B981),
      'icon': Icons.forest,
    },
    'Chakra Tones': {
      'frequency': '396-963 Hz',
      'description': 'Full chakra alignment sequence',
      'color': const Color(0xFFEC4899),
      'icon': Icons.blur_circular,
    },
  };

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));
    
    _breathingAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _waveController.dispose();
    _breathingController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Sound Bath',
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
          
          // Animated waves
          if (isPlaying)
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: WavePainter(
                    animationValue: _waveAnimation.value,
                    color: soundData[selectedSound]!['color'] as Color,
                  ),
                );
              },
            ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Central visualization
                  _buildCentralVisualization(),
                  
                  const SizedBox(height: 40),
                  
                  // Sound selector
                  _buildSoundSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // Duration selector
                  _buildDurationSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // Breathing guide
                  if (isPlaying) _buildBreathingGuide(),
                  
                  const SizedBox(height: 32),
                  
                  // Play controls
                  _buildPlayControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralVisualization() {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathingAnimation, _glowAnimation]),
      builder: (context, child) {
        return Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (soundData[selectedSound]!['color'] as Color)
                    .withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 50,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Transform.scale(
                scale: isPlaying ? _breathingAnimation.value : 1.0,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        (soundData[selectedSound]!['color'] as Color)
                            .withOpacity(0.1),
                        (soundData[selectedSound]!['color'] as Color)
                            .withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Middle ring
              Transform.scale(
                scale: isPlaying ? _breathingAnimation.value * 0.8 : 0.8,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        (soundData[selectedSound]!['color'] as Color)
                            .withOpacity(0.2),
                        (soundData[selectedSound]!['color'] as Color)
                            .withOpacity(0.4),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Center
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: soundData[selectedSound]!['color'] as Color,
                  boxShadow: [
                    BoxShadow(
                      color: (soundData[selectedSound]!['color'] as Color)
                          .withOpacity(0.8),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  soundData[selectedSound]!['icon'] as IconData,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSoundSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Sound',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: soundData.length,
            itemBuilder: (context, index) {
              final sound = soundData.keys.elementAt(index);
              final data = soundData[sound]!;
              final isSelected = sound == selectedSound;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSound = sound;
                  });
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isSelected
                                ? [
                                    (data['color'] as Color).withOpacity(0.3),
                                    (data['color'] as Color).withOpacity(0.1),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                          ),
                          border: Border.all(
                            color: isSelected
                                ? (data['color'] as Color).withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              data['icon'] as IconData,
                              color: isSelected
                                  ? data['color'] as Color
                                  : Colors.white70,
                              size: 32,
                            ),
                            Text(
                              sound,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              data['frequency'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          soundData[selectedSound]!['description'] as String,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duration',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 15, 20, 30].map((duration) {
                  final isSelected = duration == selectedDuration;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDuration = duration;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (soundData[selectedSound]!['color'] as Color)
                                .withOpacity(0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? soundData[selectedSound]!['color'] as Color
                              : Colors.white30,
                        ),
                      ),
                      child: Text(
                        '$duration min',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingGuide() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _breathingAnimation.value > 1.0 ? 'Breathe In' : 'Breathe Out',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white70),
            onPressed: () {
              // Previous sound logic
            },
          ),
        ),
        
        const SizedBox(width: 20),
        
        // Play/Pause button
        GestureDetector(
          onTap: () {
            setState(() {
              isPlaying = !isPlaying;
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  soundData[selectedSound]!['color'] as Color,
                  (soundData[selectedSound]!['color'] as Color).withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (soundData[selectedSound]!['color'] as Color)
                      .withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        
        const SizedBox(width: 20),
        
        // Next button
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white70),
            onPressed: () {
              // Next sound logic
            },
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 5; i++) {
      final progress = (animationValue + i * 0.2) % 1.0;
      final radius = size.width * 0.3 * progress;
      final opacity = 1.0 - progress;
      
      paint.color = color.withOpacity(opacity * 0.3);
      
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}