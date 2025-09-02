import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../data/crystal_database.dart';
import '../services/offline_crystal_service.dart';
import '../config/enhanced_theme.dart';
import '../widgets/common/enhanced_mystical_widgets.dart';
import '../widgets/animations/enhanced_animations.dart';
import '../widgets/common/mystical_card.dart';
import '../screens/collection_screen.dart';
import '../screens/crystal_info_screen.dart';

class DailyCrystalCard extends StatefulWidget {
  const DailyCrystalCard({Key? key}) : super(key: key);

  @override
  State<DailyCrystalCard> createState() => _DailyCrystalCardState();
}

class _DailyCrystalCardState extends State<DailyCrystalCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late CrystalData _dailyCrystal;
  late Map<String, dynamic> _reading;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.repeat(reverse: true);
    
    _dailyCrystal = OfflineCrystalService.getDailyCrystal();
    _reading = OfflineCrystalService.generateReading();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDailyReading(context),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: MysticalCard(
              primaryColor: CrystalGrimoireTheme.mysticPurple,
              secondaryColor: CrystalGrimoireTheme.royalPurple,
              enableGlow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CrystalGrimoireTheme.celestialGold.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wb_sunny_outlined,
                          color: CrystalGrimoireTheme.celestialGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Crystal of the Day',
                              style: TextStyle(
                                color: CrystalGrimoireTheme.celestialGold,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _dailyCrystal.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.5),
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Crystal properties
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildPropertyChip(
                              Icons.color_lens_outlined,
                              _dailyCrystal.colorDescription.split(',').first.trim(),
                              _getCrystalColor(_dailyCrystal),
                            ),
                            const SizedBox(width: 8),
                            _buildPropertyChip(
                              Icons.self_improvement,
                              _dailyCrystal.chakras.first,
                              _getChakraColor(_dailyCrystal.chakras.first),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _dailyCrystal.metaphysicalProperties.first,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Moon phase and energy
                  Row(
                    children: [
                      Icon(
                        _getMoonIcon(_reading['moonPhase']),
                        color: CrystalGrimoireTheme.moonlightWhite,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _reading['moonPhase'],
                        style: TextStyle(
                          color: CrystalGrimoireTheme.moonlightWhite.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.flash_on,
                        color: CrystalGrimoireTheme.etherealBlue,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _reading['dayEnergy'],
                        style: TextStyle(
                          color: CrystalGrimoireTheme.etherealBlue.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showDailyReading(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CrystalGrimoireTheme.royalPurple,
              CrystalGrimoireTheme.deepSpace,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: CrystalGrimoireTheme.celestialGold,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Daily Crystal Reading',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Crystal showcase
                  MysticalCard(
                    primaryColor: _getCrystalColor(_dailyCrystal),
                    secondaryColor: CrystalGrimoireTheme.royalPurple,
                    child: Column(
                      children: [
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                _getCrystalColor(_dailyCrystal).withOpacity(0.6),
                                _getCrystalColor(_dailyCrystal).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Center(
                            child: PulsingGlow(
                              glowColor: Colors.purple,
                              child: Icon(
                                Icons.diamond,
                                size: 80,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _dailyCrystal.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _dailyCrystal.scientificName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Personal message
                  MysticalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.message_outlined,
                              color: CrystalGrimoireTheme.amethyst,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Personal Message',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _reading['message'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Affirmation
                  MysticalCard(
                    primaryColor: CrystalGrimoireTheme.cosmicViolet,
                    secondaryColor: CrystalGrimoireTheme.deepSpace,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.format_quote,
                          color: CrystalGrimoireTheme.celestialGold,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _reading['affirmation'],
                          style: const TextStyle(
                            color: CrystalGrimoireTheme.celestialGold,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Ritual
                  MysticalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.spa_outlined,
                              color: CrystalGrimoireTheme.successGreen,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Daily Ritual',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _reading['ritual'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CrystalInfoScreen(
                                  crystalId: _dailyCrystal.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Learn More'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CrystalGrimoireTheme.mysticPurple,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CollectionScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.explore),
                          label: const Text('Collection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CrystalGrimoireTheme.amethyst,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  IconData _getMoonIcon(String phase) {
    switch (phase) {
      case 'New Moon': return Icons.brightness_1_outlined;
      case 'Full Moon': return Icons.brightness_1;
      case 'Waxing Crescent':
      case 'Waxing Gibbous': return Icons.brightness_2;
      case 'Waning Crescent':
      case 'Waning Gibbous': return Icons.brightness_3;
      default: return Icons.brightness_4;
    }
  }

  Color _getCrystalColor(CrystalData crystal) {
    if (crystal.colorDescription.toLowerCase().contains('purple')) {
      return CrystalGrimoireTheme.amethyst;
    } else if (crystal.colorDescription.toLowerCase().contains('pink')) {
      return CrystalGrimoireTheme.crystalRose;
    } else if (crystal.colorDescription.toLowerCase().contains('blue')) {
      return CrystalGrimoireTheme.etherealBlue;
    } else if (crystal.colorDescription.toLowerCase().contains('green')) {
      return Colors.green;
    } else if (crystal.colorDescription.toLowerCase().contains('yellow')) {
      return CrystalGrimoireTheme.celestialGold;
    } else if (crystal.colorDescription.toLowerCase().contains('black')) {
      return Colors.grey[800]!;
    } else if (crystal.colorDescription.toLowerCase().contains('white')) {
      return Colors.white;
    }
    return CrystalGrimoireTheme.mysticPurple;
  }

  Color _getChakraColor(String chakra) {
    switch (chakra) {
      case 'Root': return Colors.red;
      case 'Sacral': return Colors.orange;
      case 'Solar Plexus': return Colors.yellow;
      case 'Heart': return Colors.green;
      case 'Throat': return Colors.blue;
      case 'Third Eye': return Colors.indigo;
      case 'Crown': return Colors.purple;
      default: return CrystalGrimoireTheme.mysticPurple;
    }
  }
}