import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/floating_crystals.dart';
import '../widgets/holographic_button.dart';
import 'crystal_identification_screen.dart';
import 'collection_screen.dart';
import 'moon_rituals_screen.dart';
import 'crystal_healing_screen.dart';
import 'dream_journal_screen.dart';
import 'sound_bath_screen.dart';
import 'marketplace_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    // Float animation for crystals
    _floatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(
      begin: -15.0,
      end: 15.0,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
    
    // Pulse animation for glow effects
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: AppTheme.mysticalShader,
          child: const Text(
            '✨ Crystal Grimoire ✨',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppTheme.crystalGlow),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AccountScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mystical gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.deepMystical,
                  AppTheme.darkViolet,
                  AppTheme.midnightBlue,
                ],
              ),
            ),
          ),
          
          // Animated grid overlay (from visual_codex)
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/grid.png'),
                    repeat: ImageRepeat.repeat,
                    opacity: 0.05,
                    alignment: Alignment(
                      _floatAnimation.value / 100,
                      _floatAnimation.value / 100,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Floating crystals background
          const FloatingCrystals(),
          
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Crystal of the Day
                  SliverToBoxAdapter(
                    child: _buildCrystalOfTheDay(),
                  ),
                  
                  // Feature Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                      delegate: SliverChildListDelegate([
                        _buildFeatureCard(
                          title: 'Crystal ID',
                          icon: Icons.camera_alt,
                          gradientColors: [AppTheme.amethystPurple, AppTheme.cosmicPurple],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CrystalIdentificationScreen()),
                          ),
                        ),
                        _buildFeatureCard(
                          title: 'Collection',
                          icon: Icons.diamond,
                          gradientColors: [AppTheme.blueViolet, AppTheme.mysticPink],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CollectionScreen()),
                          ),
                        ),
                        _buildFeatureCard(
                          title: 'Moon Rituals',
                          icon: Icons.nightlight_round,
                          gradientColors: [AppTheme.mysticPink, AppTheme.plum],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MoonRitualScreen()),
                          ),
                        ),
                        _buildFeatureCard(
                          title: 'Crystal Healing',
                          icon: Icons.healing,
                          gradientColors: [AppTheme.cosmicPurple, AppTheme.holoBlue],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CrystalHealingScreen()),
                          ),
                        ),
                        _buildFeatureCard(
                          title: 'Dream Journal',
                          icon: Icons.auto_stories,
                          gradientColors: [AppTheme.holoPink, AppTheme.amethystPurple],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => JournalScreen()),
                          ),
                        ),
                        _buildFeatureCard(
                          title: 'Sound Bath',
                          icon: Icons.music_note,
                          gradientColors: [AppTheme.holoBlue, AppTheme.holoYellow],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SoundBathScreen()),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  
                  // Marketplace Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: HolographicButton(
                        text: '🛍️ Crystal Marketplace',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MarketplaceScreen()),
                        ),
                      ),
                    ),
                  ),
                  
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCrystalOfTheDay() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(20),
          child: GlassmorphicContainer(
            borderRadius: 25,
            blur: 20,
            opacity: 0.1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: AppTheme.holographicShader,
                    child: const Text(
                      '🔮 Crystal of the Day',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.amethystPurple.withOpacity(_pulseAnimation.value),
                          AppTheme.cosmicPurple.withOpacity(_pulseAnimation.value * 0.5),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.amethystPurple.withOpacity(_pulseAnimation.value * 0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.diamond,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Amethyst',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.crystalGlow,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Stone of spiritual protection and purification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value * 0.2),
          child: GestureDetector(
            onTap: onTap,
            child: GlassmorphicContainer(
              borderRadius: 20,
              blur: 15,
              opacity: 0.1,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientColors[0].withOpacity(0.2),
                  gradientColors[1].withOpacity(0.1),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: gradientColors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.crystalGlow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}