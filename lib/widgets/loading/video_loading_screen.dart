import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:io';

class VideoLoadingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final String message;
  final Duration duration;

  const VideoLoadingScreen({
    Key? key,
    required this.onComplete,
    this.message = 'Processing...',
    this.duration = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<VideoLoadingScreen> createState() => _VideoLoadingScreenState();
}

class _VideoLoadingScreenState extends State<VideoLoadingScreen> 
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _sparkleAnimation;

  // Real loading videos from the loading videos directory
  final List<String> _loadingVideos = [
    'assets/videos/loading/20250530_0201_Chakras in Color_loop_01jwfweyxyfcsss2qgxtt5yth1.mp4',
    'assets/videos/loading/20250530_0220_Crystal Metamorphosis Magic_simple_compose_01jwfxkdd7f25v9f6x5b59qnnk.mp4',
    'assets/videos/loading/20250530_0223_Crystal Cave Wonder_simple_compose_01jwfxqcx1fe3rjdbpgdyf40xp.mp4',
    'assets/videos/loading/20250530_0225_Gemstone Universe_simple_compose_01jwfxwhkzewct1ckckee9z0qq.mp4',
    'assets/videos/loading/20250530_0229_Gemstone Mandala Magic_simple_compose_01jwfy2wbee9pb7ptyzz25a099.mp4',
    'assets/videos/loading/20250530_0238_Monochrome Chakra Gems_remix_01jwfyjq8rfq3b2tshr3z6550s.mp4',
    'assets/videos/loading/20250530_0244_Crystal Heart Symphony_simple_compose_01jwfyyqw0efqbedandt64xqvf.mp4',
    'assets/videos/loading/20250530_0246_Mesmerizing Mandala Magic_remix_01jwfz1aycf5r9kebzw1x57zv6.mp4',
    'assets/videos/loading/20250530_0248_Crystalline Transcendence Journey_simple_compose_01jwfz5m9jf7rb019qeyazzr3n.mp4',
    'assets/videos/loading/20250530_0254_Ethereal Heart Connection_loop_01jwfzg6t5fnxa6j4k2rc23es4.mp4',
  ];

  late String _selectedVideo;

  @override
  void initState() {
    super.initState();
    
    // Randomly select a loading video
    _selectedVideo = _loadingVideos[math.Random().nextInt(_loadingVideos.length)];
    
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut)
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.linear)
    );
    
    _startLoading();
  }

  void _startLoading() async {
    _progressController.forward();
    
    // Wait for animation to complete
    await Future.delayed(widget.duration);
    
    // Complete callback
    widget.onComplete();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background video placeholder
          _buildVideoBackground(),
          
          // Overlay with loading content
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Loading animation
                  _buildLoadingAnimation(),
                  
                  const SizedBox(height: 32),
                  
                  // Loading message
                  Text(
                    widget.message,
                    style: GoogleFonts.cinzel(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 8,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Progress bar
                  _buildProgressBar(),
                  
                  const SizedBox(height: 24),
                  
                  // Fun loading text
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Text(
                        _getLoadingText(_progressAnimation.value),
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Skip button (top right)
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: widget.onComplete,
              child: Text(
                'Skip',
                style: GoogleFonts.lato(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground() {
    // In a real implementation, this would show the actual video
    // For now, we'll create an animated background
    return AnimatedBuilder(
      animation: _sparkleAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.cos(_sparkleAnimation.value) * 0.3,
                math.sin(_sparkleAnimation.value) * 0.3,
              ),
              colors: [
                Colors.deepPurple.withOpacity(0.6),
                Colors.indigo.withOpacity(0.4),
                Colors.black,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Floating particles
              ...List.generate(20, (index) {
                final offset = (index * 0.3 + _sparkleAnimation.value) % (2 * math.pi);
                return Positioned(
                  left: 50 + math.cos(offset) * 150 + MediaQuery.of(context).size.width * 0.3,
                  top: 100 + math.sin(offset) * 200 + MediaQuery.of(context).size.height * 0.3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF20B2AA), Color(0xFFFF4500)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.diamond,
                  size: 60,
                  color: Colors.white,
                ),
                // Rotating sparkles
                AnimatedBuilder(
                  animation: _sparkleAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _sparkleAnimation.value,
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 80,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                minHeight: 6,
              );
            },
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Text(
                '${(_progressAnimation.value * 100).round()}%',
                style: GoogleFonts.lato(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getLoadingText(double progress) {
    if (progress < 0.2) {
      return 'Connecting to cosmic energies...';
    } else if (progress < 0.4) {
      return 'Aligning crystal frequencies...';
    } else if (progress < 0.6) {
      return 'Consulting ancient wisdom...';
    } else if (progress < 0.8) {
      return 'Channeling spiritual insights...';
    } else {
      return 'Preparing your reading...';
    }
  }
}