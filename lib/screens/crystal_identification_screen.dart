import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../services/crystal_service.dart';
import '../services/auth_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/holographic_button.dart';
import '../widgets/floating_crystals.dart';

class CrystalIdentificationScreen extends StatefulWidget {
  const CrystalIdentificationScreen({super.key});

  @override
  State<CrystalIdentificationScreen> createState() => _CrystalIdentificationScreenState();
}

class _CrystalIdentificationScreenState extends State<CrystalIdentificationScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  Map<String, dynamic>? _identificationResult;
  bool _isIdentifying = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
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
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _identificationResult = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _identifyCrystal() async {
    if (_imageBytes == null) {
      _showError('Please select an image first');
      return;
    }

    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated) {
      _showError('Please sign in to identify crystals');
      return;
    }

    setState(() {
      _isIdentifying = true;
    });

    try {
      final crystalService = context.read<CrystalService>();
      final result = await crystalService.identifyCrystal(_imageBytes!);
      
      setState(() {
        _identificationResult = result;
        _isIdentifying = false;
      });
      
      if (result != null) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _isIdentifying = false;
      });
      _showError('Identification failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    if (_identificationResult == null) return;
    
    final crystal = _identificationResult!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkViolet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.crystalGlow.withOpacity(0.3)),
        ),
        title: Text(
          '🔮 Crystal Identified!',
          style: TextStyle(color: AppTheme.crystalGlow),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crystal['identification']['name'] ?? 'Unknown',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.mysticPink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              crystal['description'] ?? 'No description available',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            Text(
              'Confidence: ${crystal['identification']['confidence'] ?? 0}%',
              style: TextStyle(color: AppTheme.holoBlue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.crystalGlow)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addToCollection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amethystPurple.withOpacity(0.3),
              foregroundColor: AppTheme.crystalGlow,
            ),
            child: const Text('Add to Collection'),
          ),
        ],
      ),
    );
  }

  void _addToCollection() {
    // TODO: Implement add to collection functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Crystal added to your collection! 🔮'),
        backgroundColor: AppTheme.amethystPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            '🔍 Crystal Identification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.crystalGlow),
          onPressed: () => Navigator.pop(context),
        ),
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
          const FloatingCrystals(crystalCount: 10, maxSize: 30),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Image preview area
                  GlassmorphicContainer(
                    borderRadius: 25,
                    blur: 20,
                    opacity: 0.1,
                    child: Container(
                      height: 300,
                      padding: const EdgeInsets.all(20),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              AppTheme.crystalGlow.withOpacity(0.3),
                                              AppTheme.cosmicPurple.withOpacity(0.1),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: AppTheme.crystalGlow.withOpacity(0.5),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 50,
                                          color: AppTheme.crystalGlow,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Upload Crystal Image',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: AppTheme.crystalGlow,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Take a photo or select from gallery',
                                        style: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: HolographicButton(
                          text: '📷 Camera',
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: Icons.camera_alt,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: HolographicButton(
                          text: '🖼️ Gallery',
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: Icons.photo_library,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Identify button
                  if (_imageBytes != null) ...[
                    HolographicButton(
                      text: _isIdentifying ? 'Identifying...' : '🔮 Identify Crystal',
                      onPressed: _isIdentifying ? () {} : _identifyCrystal,
                      icon: _isIdentifying ? Icons.hourglass_empty : Icons.auto_fix_high,
                    ),
                  ],
                  
                  const SizedBox(height: 30),
                  
                  // Results section
                  if (_identificationResult != null) ...[
                    _buildResultsSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    final crystal = _identificationResult!;
    final identification = crystal['identification'] ?? {};
    final metaphysical = crystal['metaphysical_properties'] ?? {};
    
    return GlassmorphicContainer(
      borderRadius: 20,
      blur: 15,
      opacity: 0.1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.diamond, color: AppTheme.crystalGlow, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    identification['name'] ?? 'Unknown Crystal',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.crystalGlow,
                    ),
                  ),
                ),
              ],
            ),
            
            if (identification['variety'] != null && identification['variety'].isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                identification['variety'],
                style: TextStyle(
                  color: AppTheme.mysticPink,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            const SizedBox(height: 15),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.holoBlue.withOpacity(0.2),
                    AppTheme.holoPink.withOpacity(0.2),
                  ],
                ),
              ),
              child: Text(
                'Confidence: ${identification['confidence'] ?? 0}%',
                style: TextStyle(
                  color: AppTheme.holoBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              crystal['description'] ?? 'No description available',
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            
            if (metaphysical['healing_properties'] != null) ...[
              const SizedBox(height: 20),
              Text(
                '✨ Healing Properties',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.mysticPink,
                ),
              ),
              const SizedBox(height: 10),
              ...((metaphysical['healing_properties'] as List?)?.map<Widget>((property) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      const Text('• ', style: TextStyle(color: AppTheme.crystalGlow)),
                      Expanded(
                        child: Text(
                          property.toString(),
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ) ?? []),
            ],
            
            if (metaphysical['primary_chakras'] != null) ...[
              const SizedBox(height: 15),
              Text(
                '🌈 Chakras',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mysticPink,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: ((metaphysical['primary_chakras'] as List?)?.map<Widget>((chakra) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: AppTheme.cosmicPurple.withOpacity(0.3),
                      border: Border.all(color: AppTheme.cosmicPurple.withOpacity(0.5)),
                    ),
                    child: Text(
                      chakra.toString(),
                      style: TextStyle(
                        color: AppTheme.crystalGlow,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ) ?? []).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}