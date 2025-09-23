import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import "../widgets/no_particles.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _progressAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Logo animation (scale + rotation)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    
    // Text animation (fade + slide)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    );
    
    // Progress animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );
    
    _startAnimations();
  }
  
  void _startAnimations() async {
    // Start logo animation
    _logoController.forward();
    
    // Delay then start text animation
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    
    // Start progress animation
    await Future.delayed(const Duration(milliseconds: 800));
    _progressController.forward();
    
    // Navigate to auth wrapper after animations complete
    await Future.delayed(const Duration(milliseconds: 4000));
    final hasSeen = await StorageService.hasSeenOnboarding();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      hasSeen ? '/auth-check' : '/onboarding',
    );
  }
  
  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mystical gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                colors: [
                  AppTheme.deepMystical,
                  AppTheme.darkViolet,
                  Color(0xFF000000),
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
          ),
          
          // Floating crystals background (reduced for performance)
          const SimpleGradientParticles(particleCount: 3),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated crystal logo
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: Transform.rotate(
                        angle: _logoAnimation.value * math.pi * 2,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.crystalGlow.withOpacity(0.8),
                                AppTheme.amethystPurple.withOpacity(0.6),
                                AppTheme.cosmicPurple.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.crystalGlow.withOpacity(0.3),
                                blurRadius: 50,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.diamond,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Animated title
                AnimatedBuilder(
                  animation: _textAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - _textAnimation.value)),
                      child: Opacity(
                        opacity: _textAnimation.value,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  AppTheme.crystalGlow,
                                  AppTheme.mysticPink,
                                  AppTheme.cosmicPurple,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Crystal Grimoire',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 10),
                            
                            Text(
                              '✨ Your Mystical Journey Begins ✨',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.crystalGlow.withOpacity(0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 80),
                
                // Animated progress indicator
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 200 * _progressAnimation.value,
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.holoBlue,
                                    AppTheme.holoPink,
                                    AppTheme.holoYellow,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.holoBlue.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Opacity(
                          opacity: _progressAnimation.value,
                          child: Text(
                            'Awakening your crystal consciousness...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Mystical particles overlay
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return CustomPaint(
                painter: MysticalParticlesPainter(
                  animation: _logoController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
        ],
      ),
    );
  }
}

class MysticalParticlesPainter extends CustomPainter {
  final double animation;
  
  MysticalParticlesPainter({required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3 + 1;
      final opacity = (0.3 + random.nextDouble() * 0.7) * animation;
      
      paint.color = [
        AppTheme.crystalGlow,
        AppTheme.mysticPink,
        AppTheme.cosmicPurple,
        AppTheme.holoBlue,
      ][i % 4].withOpacity(opacity);
      
      // Create twinkling effect
      final twinkle = math.sin((animation * 10 + i) * math.pi) * 0.5 + 0.5;
      final adjustedRadius = radius * (0.5 + twinkle * 0.5);
      
      canvas.drawCircle(
        Offset(x, y),
        adjustedRadius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(MysticalParticlesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}