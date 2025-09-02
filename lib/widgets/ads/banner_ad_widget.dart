import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final List<Map<String, dynamic>> _mockAds = [
    {
      'title': 'Crystal Healing Course',
      'subtitle': 'Learn from certified masters',
      'color': Colors.purple,
      'icon': Icons.school,
    },
    {
      'title': 'Premium Crystals Store',
      'subtitle': 'Authentic gems worldwide',
      'color': Colors.indigo,
      'icon': Icons.store,
    },
    {
      'title': 'Meditation App',
      'subtitle': 'Find your inner peace',
      'color': Colors.deepPurple,
      'icon': Icons.self_improvement,
    },
    {
      'title': 'Astrology Reading',
      'subtitle': 'Discover your destiny',
      'color': Colors.blueAccent,
      'icon': Icons.star,
    },
  ];

  late Map<String, dynamic> _currentAd;

  @override
  void initState() {
    super.initState();
    
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear)
    );
    
    // Randomly select an ad
    _currentAd = _mockAds[math.Random().nextInt(_mockAds.length)];
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            _currentAd['color'].withOpacity(0.3),
            _currentAd['color'].withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: _currentAd['color'].withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _handleAdClick,
          child: Stack(
            children: [
              // Shimmer effect
              AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return Positioned(
                    left: -200 + (_shimmerAnimation.value * 400),
                    top: 0,
                    bottom: 0,
                    width: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Ad content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Ad icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentAd['color'].withOpacity(0.2),
                      ),
                      child: Icon(
                        _currentAd['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Ad text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentAd['title'],
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _currentAd['subtitle'],
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // "Ad" label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ad',
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
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
    );
  }

  void _handleAdClick() {
    // Show engagement dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          _currentAd['title'],
          style: GoogleFonts.cinzel(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentAd['icon'],
              size: 48,
              color: _currentAd['color'],
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you for your interest! This is a demo ad for ${_currentAd['title']}.',
              style: GoogleFonts.lato(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'In the full version, this would open the advertiser\'s content.',
              style: GoogleFonts.lato(
                fontSize: 12,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showRewardDialog();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _currentAd['color']),
            child: const Text('Learn More'),
          ),
        ],
      ),
    );
  }

  void _showRewardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          '🎁 Ad Reward',
          style: GoogleFonts.cinzel(color: Colors.white),
        ),
        content: Text(
          'Thanks for engaging! You\'ve earned +1 Crystal Identification for watching this ad.',
          style: GoogleFonts.lato(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }
}