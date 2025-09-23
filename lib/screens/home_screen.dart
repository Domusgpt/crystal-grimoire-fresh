import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/crystal_service.dart';
import '../widgets/glassmorphic_container.dart';
import "../widgets/no_particles.dart";
import '../widgets/holographic_button.dart';
import 'crystal_identification_screen.dart';
import 'collection_screen.dart';
import 'moon_rituals_screen.dart';
import 'crystal_healing_screen.dart';
import 'dream_journal_screen.dart';
import 'sound_bath_screen.dart';
import 'marketplace_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dailyCrystal;
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDailyCrystal();
  }

  Future<void> _loadUserData() async {
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated && AuthService.currentUser != null) {
      setState(() {
        _userName = AuthService.currentUser!.displayName ?? 'Crystal Seeker';
      });
    }
  }

  Future<void> _loadDailyCrystal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get real crystal data from Firebase
      final crystalService = context.read<CrystalService>();
      final crystalData = await crystalService.getDailyCrystal();
      
      setState(() {
        _dailyCrystal = crystalData ?? {
          'name': 'Amethyst',
          'description': 'A powerful crystal for spiritual growth, protection, and clarity. Amethyst enhances intuition and promotes peaceful energy.',
          'properties': ['Spiritual Growth', 'Protection', 'Clarity', 'Peace']
        };
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to a real crystal instead of placeholder
      setState(() {
        _dailyCrystal = {
          'name': 'Clear Quartz',
          'description': 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone.',
          'properties': ['Amplification', 'Healing', 'Clarity', 'Energy']
        };
        _isLoading = false;
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
            icon: const Icon(Icons.notifications_none, color: AppTheme.crystalGlow),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.crystalGlow),
            tooltip: 'Help & Tutorials',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppTheme.crystalGlow),
            tooltip: 'Profile',
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
          // Background
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
          
          // Floating crystals
          const SimpleGradientParticles(particleCount: 5),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Crystal of the Day
                  _buildCrystalOfTheDay(),
                  
                  const SizedBox(height: 30),
                  
                  // Feature Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
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
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Marketplace Button
                  HolographicButton(
                    text: '🛍️ Crystal Marketplace',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MarketplaceScreen()),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCrystalOfTheDay() {
    return GlassmorphicContainer(
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
                gradient: const RadialGradient(
                  colors: [
                    AppTheme.amethystPurple,
                    AppTheme.cosmicPurple,
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amethystPurple.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
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
            Text(
              _isLoading ? 'Loading...' : (_dailyCrystal?['name'] ?? 'Clear Quartz'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.crystalGlow,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isLoading ? 'Discovering your daily crystal...' : (_dailyCrystal?['description'] ?? 'The master healer crystal that amplifies energy and intentions.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            if (!_isLoading && _dailyCrystal?['properties'] != null) ...[
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                alignment: WrapAlignment.center,
                children: (_dailyCrystal!['properties'] as List).map<Widget>((property) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: AppTheme.cosmicPurple.withOpacity(0.3),
                      border: Border.all(color: AppTheme.cosmicPurple.withOpacity(0.5)),
                    ),
                    child: Text(
                      property.toString(),
                      style: const TextStyle(
                        color: AppTheme.crystalGlow,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
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
    );
  }
}