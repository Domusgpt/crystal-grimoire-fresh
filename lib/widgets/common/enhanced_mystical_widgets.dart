import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../animations/mystical_animations.dart';
import 'mystical_card.dart';

class EnhancedCrystalOfTheDay extends StatefulWidget {
  final String crystalName;
  final String crystalType;
  final String description;
  final Color crystalColor;
  final VoidCallback? onTap;

  const EnhancedCrystalOfTheDay({
    Key? key,
    required this.crystalName,
    required this.crystalType,
    required this.description,
    required this.crystalColor,
    this.onTap,
  }) : super(key: key);

  @override
  State<EnhancedCrystalOfTheDay> createState() => _EnhancedCrystalOfTheDayState();
}

class _EnhancedCrystalOfTheDayState extends State<EnhancedCrystalOfTheDay>
    with TickerProviderStateMixin {
  late AnimationController _sparkleController;
  late AnimationController _pulseController;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MysticalCard(
      primaryColor: widget.crystalColor,
      secondaryColor: widget.crystalColor.withOpacity(0.7),
      enableGlow: true,
      onTap: widget.onTap,
      height: 200,
      child: Stack(
        children: [
          // Background sparkles
          ...List.generate(8, (index) {
            return AnimatedBuilder(
              animation: _sparkleAnimation,
              builder: (context, child) {
                final offset = (index * 0.3 + _sparkleAnimation.value) % 1.0;
                return Positioned(
                  left: (math.sin(offset * 2 * math.pi + index) * 0.3 + 0.5) * 300,
                  top: (math.cos(offset * 2 * math.pi + index) * 0.3 + 0.5) * 180,
                  child: CrystalSparkle(
                    size: 12 + (index % 3) * 4,
                    color: Colors.white.withOpacity(0.6),
                  ),
                );
              },
            );
          }),
          
          // Main content
          Column(
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Crystal of the Day',
                    style: GoogleFonts.cinzel(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Crystal visualization
              Expanded(
                child: Row(
                  children: [
                    // Crystal icon with pulse effect
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  widget.crystalColor,
                                  widget.crystalColor.withOpacity(0.6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.crystalColor.withOpacity(0.6),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.diamond,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Crystal info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.crystalName,
                            style: GoogleFonts.cinzel(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.crystalType,
                            style: GoogleFonts.crimsonText(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.description,
                            style: GoogleFonts.crimsonText(
                              fontSize: 12,
                              color: Colors.white60,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EnhancedUsageWidget extends StatefulWidget {
  final int currentUsage;
  final int maxUsage;
  final String usageType;
  final Color progressColor;
  final VoidCallback? onTap;

  const EnhancedUsageWidget({
    Key? key,
    required this.currentUsage,
    required this.maxUsage,
    required this.usageType,
    required this.progressColor,
    this.onTap,
  }) : super(key: key);

  @override
  State<EnhancedUsageWidget> createState() => _EnhancedUsageWidgetState();
}

class _EnhancedUsageWidgetState extends State<EnhancedUsageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.currentUsage / widget.maxUsage,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MysticalCard(
      primaryColor: widget.progressColor,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.usageType,
                style: GoogleFonts.cinzel(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Text(
                '${widget.currentUsage}/${widget.maxUsage}',
                style: GoogleFonts.cinzel(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Animated progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white24,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            widget.progressColor,
                            widget.progressColor.withOpacity(0.8),
                          ],
                        ),
                      ),
                      width: MediaQuery.of(context).size.width * _progressAnimation.value,
                    ),
                    // Shimmer effect on progress bar
                    if (_progressAnimation.value > 0)
                      ShimmerWidget(
                        baseColor: Colors.transparent,
                        highlightColor: Colors.white.withOpacity(0.3),
                        child: Container(
                          height: 8,
                          width: MediaQuery.of(context).size.width * _progressAnimation.value,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Usage status text
          Text(
            _getUsageStatusText(),
            style: GoogleFonts.crimsonText(
              fontSize: 12,
              color: _getUsageStatusColor(),
            ),
          ),
        ],
      ),
    );
  }

  String _getUsageStatusText() {
    final percentage = (widget.currentUsage / widget.maxUsage * 100).round();
    
    if (percentage >= 90) {
      return 'Almost at limit • Consider upgrading';
    } else if (percentage >= 75) {
      return 'Getting close to limit';
    } else if (percentage >= 50) {
      return 'Halfway through your allowance';
    } else {
      return 'Plenty of usage remaining';
    }
  }

  Color _getUsageStatusColor() {
    final percentage = widget.currentUsage / widget.maxUsage;
    
    if (percentage >= 0.9) {
      return Colors.red;
    } else if (percentage >= 0.75) {
      return Colors.orange;
    } else {
      return Colors.white54;
    }
  }
}

class EnhancedMoonPhaseWidget extends StatefulWidget {
  final String moonPhase;
  final String astrologyInfo;
  final VoidCallback? onTap;

  const EnhancedMoonPhaseWidget({
    Key? key,
    required this.moonPhase,
    required this.astrologyInfo,
    this.onTap,
  }) : super(key: key);

  @override
  State<EnhancedMoonPhaseWidget> createState() => _EnhancedMoonPhaseWidgetState();
}

class _EnhancedMoonPhaseWidgetState extends State<EnhancedMoonPhaseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MysticalCard(
      primaryColor: Colors.indigo,
      secondaryColor: Colors.purple,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rotating moon icon
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.yellow.withOpacity(0.8),
                            Colors.orange.withOpacity(0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getMoonIcon(),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.moonPhase,
                      style: GoogleFonts.cinzel(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.astrologyInfo,
                      style: GoogleFonts.crimsonText(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Moon phase specific guidance
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.withOpacity(0.5)),
            ),
            child: Text(
              _getMoonPhaseGuidance(),
              style: GoogleFonts.crimsonText(
                fontSize: 11,
                color: Colors.white60,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMoonIcon() {
    switch (widget.moonPhase.toLowerCase()) {
      case 'new moon':
        return Icons.brightness_1;
      case 'waxing crescent':
        return Icons.brightness_2;
      case 'first quarter':
        return Icons.brightness_3;
      case 'waxing gibbous':
        return Icons.brightness_4;
      case 'full moon':
        return Icons.brightness_5;
      case 'waning gibbous':
        return Icons.brightness_6;
      case 'last quarter':
        return Icons.brightness_7;
      case 'waning crescent':
        return Icons.brightness_1;
      default:
        return Icons.brightness_3;
    }
  }

  String _getMoonPhaseGuidance() {
    switch (widget.moonPhase.toLowerCase()) {
      case 'new moon':
        return 'Perfect time for new beginnings and setting intentions. Meditate with clear quartz.';
      case 'waxing crescent':
        return 'Focus on growth and taking action on your goals. Green aventurine supports manifestation.';
      case 'first quarter':
        return 'Time to overcome challenges and make decisions. Use citrine for confidence.';
      case 'waxing gibbous':
        return 'Refine your plans and stay persistent. Fluorite enhances mental clarity.';
      case 'full moon':
        return 'Peak energy for manifestation and completion. Moonstone amplifies lunar power.';
      case 'waning gibbous':
        return 'Express gratitude and share your wisdom. Rose quartz opens the heart.';
      case 'last quarter':
        return 'Release what no longer serves you. Black tourmaline aids in letting go.';
      case 'waning crescent':
        return 'Rest, reflect, and prepare for renewal. Amethyst supports inner wisdom.';
      default:
        return 'Connect with the lunar cycles to enhance your spiritual practice.';
    }
  }
}

class EnhancedInsightWidget extends StatefulWidget {
  final String title;
  final String insight;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const EnhancedInsightWidget({
    Key? key,
    required this.title,
    required this.insight,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  State<EnhancedInsightWidget> createState() => _EnhancedInsightWidgetState();
}

class _EnhancedInsightWidgetState extends State<EnhancedInsightWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MysticalCard(
      primaryColor: widget.color,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(_glowAnimation.value),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(_glowAnimation.value),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            widget.insight,
            style: GoogleFonts.crimsonText(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}