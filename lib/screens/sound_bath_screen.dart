import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SoundBathScreen extends StatefulWidget {
  const SoundBathScreen({Key? key}) : super(key: key);

  @override
  State<SoundBathScreen> createState() => _SoundBathScreenState();
}

class _ToneComponent {
  final double frequency;
  final double amplitude;
  final double? modulationFrequency;
  final double modulationDepth;
  final double phase;

  const _ToneComponent({
    required this.frequency,
    required this.amplitude,
    this.modulationFrequency,
    this.modulationDepth = 0.0,
    this.phase = 0.0,
  });
}

class _SoundscapeDefinition {
  final String frequencyLabel;
  final String description;
  final Color color;
  final IconData icon;
  final List<_ToneComponent> tones;
  final double noiseAmplitude;

  const _SoundscapeDefinition({
    required this.frequencyLabel,
    required this.description,
    required this.color,
    required this.icon,
    required this.tones,
    this.noiseAmplitude = 0.0,
  });
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

  late AudioPlayer _audioPlayer;
  Timer? _sessionTimer;

  final Map<String, _SoundscapeDefinition> _soundscapes = {
    'Crystal Bowl': _SoundscapeDefinition(
      frequencyLabel: '432 Hz',
      description: 'Pure crystal vibrations for deep healing',
      color: const Color(0xFF9333EA),
      icon: Icons.album,
      tones: const [
        _ToneComponent(frequency: 432, amplitude: 0.7),
        _ToneComponent(
          frequency: 864,
          amplitude: 0.25,
          modulationFrequency: 0.1,
          modulationDepth: 0.3,
        ),
      ],
    ),
    'Tibetan Bowl': _SoundscapeDefinition(
      frequencyLabel: '528 Hz',
      description: 'Ancient harmonic healing frequencies',
      color: const Color(0xFFD97706),
      icon: Icons.circle,
      tones: const [
        _ToneComponent(frequency: 528, amplitude: 0.65),
        _ToneComponent(
          frequency: 396,
          amplitude: 0.2,
          modulationFrequency: 0.07,
          modulationDepth: 0.35,
          phase: math.pi / 3,
        ),
        _ToneComponent(
          frequency: 792,
          amplitude: 0.15,
          modulationFrequency: 0.11,
          modulationDepth: 0.25,
          phase: math.pi / 2,
        ),
      ],
    ),
    'Ocean Waves': _SoundscapeDefinition(
      frequencyLabel: 'Natural',
      description: 'Calming rhythm of the sea',
      color: const Color(0xFF0EA5E9),
      icon: Icons.waves,
      tones: const [
        _ToneComponent(
          frequency: 60,
          amplitude: 0.25,
          modulationFrequency: 0.05,
          modulationDepth: 0.6,
        ),
        _ToneComponent(
          frequency: 120,
          amplitude: 0.18,
          modulationFrequency: 0.08,
          modulationDepth: 0.4,
          phase: math.pi / 4,
        ),
      ],
      noiseAmplitude: 0.35,
    ),
    'Rain Forest': _SoundscapeDefinition(
      frequencyLabel: 'Natural',
      description: 'Immersive nature chorus with gentle rain',
      color: const Color(0xFF10B981),
      icon: Icons.forest,
      tones: const [
        _ToneComponent(
          frequency: 220,
          amplitude: 0.18,
          modulationFrequency: 0.12,
          modulationDepth: 0.5,
        ),
        _ToneComponent(
          frequency: 440,
          amplitude: 0.15,
          modulationFrequency: 0.18,
          modulationDepth: 0.4,
          phase: math.pi / 5,
        ),
        _ToneComponent(
          frequency: 660,
          amplitude: 0.12,
          modulationFrequency: 0.23,
          modulationDepth: 0.4,
          phase: math.pi / 2,
        ),
      ],
      noiseAmplitude: 0.25,
    ),
    'Chakra Tones': _SoundscapeDefinition(
      frequencyLabel: '396-963 Hz',
      description: 'Full chakra alignment sequence',
      color: const Color(0xFFEC4899),
      icon: Icons.blur_circular,
      tones: const [
        _ToneComponent(frequency: 396, amplitude: 0.12),
        _ToneComponent(
          frequency: 417,
          amplitude: 0.12,
          modulationFrequency: 0.05,
          modulationDepth: 0.2,
          phase: math.pi / 6,
        ),
        _ToneComponent(frequency: 432, amplitude: 0.12),
        _ToneComponent(
          frequency: 528,
          amplitude: 0.12,
          modulationFrequency: 0.09,
          modulationDepth: 0.25,
          phase: math.pi / 4,
        ),
        _ToneComponent(
          frequency: 639,
          amplitude: 0.12,
          modulationFrequency: 0.11,
          modulationDepth: 0.25,
          phase: math.pi / 3,
        ),
        _ToneComponent(
          frequency: 741,
          amplitude: 0.1,
          modulationFrequency: 0.13,
          modulationDepth: 0.3,
          phase: math.pi / 2.2,
        ),
        _ToneComponent(
          frequency: 852,
          amplitude: 0.1,
          modulationFrequency: 0.17,
          modulationDepth: 0.28,
          phase: math.pi / 1.7,
        ),
        _ToneComponent(
          frequency: 963,
          amplitude: 0.1,
          modulationFrequency: 0.19,
          modulationDepth: 0.3,
          phase: math.pi / 1.4,
        ),
      ],
    ),
  };

  final Map<String, Uint8List> _soundBuffers = {};

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

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
    _sessionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startPlayback() async {
    final definition = _soundscapes[selectedSound];
    if (definition == null) {
      return;
    }

    try {
      final buffer = await _loadSoundscapeBytes(selectedSound, definition);
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(buffer));

      _sessionTimer?.cancel();
      _sessionTimer = Timer(Duration(minutes: selectedDuration), () async {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start sound bath: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _stopPlayback() async {
    _sessionTimer?.cancel();
    await _audioPlayer.stop();
  }

  Future<void> _togglePlayback() async {
    if (isPlaying) {
      await _stopPlayback();
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isPlaying = true;
        });
      }
      await _startPlayback();
    }
  }

  Future<void> _restartPlaybackIfNeeded() async {
    if (isPlaying) {
      await _startPlayback();
    }
  }

  Future<Uint8List> _loadSoundscapeBytes(
    String key,
    _SoundscapeDefinition definition,
  ) async {
    final cached = _soundBuffers[key];
    if (cached != null) {
      return cached;
    }

    final buffer = await Future<Uint8List>(() {
      return _generateSoundscape(definition, seed: key.hashCode);
    });
    _soundBuffers[key] = buffer;
    return buffer;
  }

  Uint8List _generateSoundscape(
    _SoundscapeDefinition definition, {
    required int seed,
    int sampleRate = 44100,
    double durationSeconds = 8.0,
  }) {
    final sampleCount = (sampleRate * durationSeconds).toInt();
    final byteData = ByteData(44 + sampleCount * 2);
    final random = math.Random(seed);
    final double twoPi = 2 * math.pi;

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      double sample = 0.0;

      for (final tone in definition.tones) {
        final modulation = (tone.modulationFrequency != null &&
                tone.modulationDepth != 0)
            ? 1 +
                tone.modulationDepth *
                    math.sin(twoPi * tone.modulationFrequency! * t + tone.phase)
            : 1.0;
        sample += math.sin(twoPi * tone.frequency * t + tone.phase) *
            tone.amplitude *
            modulation;
      }

      if (definition.noiseAmplitude > 0) {
        sample += (random.nextDouble() * 2 - 1) * definition.noiseAmplitude;
      }

      final window = 0.5 - 0.5 * math.cos(twoPi * i / (sampleCount - 1));
      sample = (sample * window).clamp(-1.0, 1.0);
      final value = (sample * 32767).round().clamp(-32768, 32767);
      byteData.setInt16(44 + i * 2, value, Endian.little);
    }

    _writeString(byteData, 0, 'RIFF');
    byteData.setUint32(4, 36 + sampleCount * 2, Endian.little);
    _writeString(byteData, 8, 'WAVE');
    _writeString(byteData, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size
    byteData.setUint16(20, 1, Endian.little); // PCM format
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    byteData.setUint16(32, 2, Endian.little); // Block align
    byteData.setUint16(34, 16, Endian.little); // Bits per sample
    _writeString(byteData, 36, 'data');
    byteData.setUint32(40, sampleCount * 2, Endian.little);

    return byteData.buffer.asUint8List();
  }

  void _writeString(ByteData data, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  void _changeSound(int direction) {
    final options = _soundscapes.keys.toList();
    if (options.isEmpty) return;

    final currentIndex = options.indexOf(selectedSound);
    if (currentIndex == -1) {
      setState(() {
        selectedSound = options.first;
      });
      _restartPlaybackIfNeeded();
      return;
    }

    var newIndex = currentIndex + direction;
    if (newIndex < 0) {
      newIndex = options.length - 1;
    } else if (newIndex >= options.length) {
      newIndex = 0;
    }

    setState(() {
      selectedSound = options[newIndex];
    });
    _restartPlaybackIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDefinition = _soundscapes[selectedSound];
    final accentColor = selectedDefinition?.color ?? const Color(0xFF9333EA);

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
                    color: accentColor,
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
    final definition = _soundscapes[selectedSound];
    final color = definition?.color ?? const Color(0xFF9333EA);
    final icon = definition?.icon ?? Icons.album;

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
                color: color.withOpacity(0.3 * _glowAnimation.value),
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
                        color.withOpacity(0.1),
                        color.withOpacity(0.3),
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
                        color.withOpacity(0.2),
                        color.withOpacity(0.4),
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
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.8),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
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
            itemCount: _soundscapes.length,
            itemBuilder: (context, index) {
              final sound = _soundscapes.keys.elementAt(index);
              final data = _soundscapes[sound]!;
              final isSelected = sound == selectedSound;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSound = sound;
                  });
                  _restartPlaybackIfNeeded();
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
                                    data.color.withOpacity(0.3),
                                    data.color.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                          ),
                          border: Border.all(
                            color: isSelected
                                ? data.color.withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              data.icon,
                              color: isSelected
                                  ? data.color
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
                              data.frequencyLabel,
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
          _soundscapes[selectedSound]?.description ?? '',
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
    final color = _soundscapes[selectedSound]?.color ?? const Color(0xFF9333EA);

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
                      _restartPlaybackIfNeeded();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color
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
    final color = _soundscapes[selectedSound]?.color ?? const Color(0xFF9333EA);

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
            onPressed: () => _changeSound(-1),
          ),
        ),
        
        const SizedBox(width: 20),
        
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlayback,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
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
            onPressed: () => _changeSound(1),
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