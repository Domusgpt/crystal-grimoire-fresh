import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../services/crystal_service.dart';
import '../services/auth_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/holographic_button.dart';
import "../widgets/no_particles.dart";

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
    final identification =
        (crystal['identification'] as Map<String, dynamic>?) ?? {};
    final report = crystal['report']?.toString();
    final reportParagraphs = _extractReportParagraphs(report);
    final summary = crystal['description']?.toString() ??
        (reportParagraphs.isNotEmpty ? reportParagraphs.first : 'No description available');
    final confidence = identification['confidence'];

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
              identification['name']?.toString() ?? 'Unknown',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.mysticPink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              style: TextStyle(color: Colors.white70),
            ),
            if (confidence != null) ...[
              const SizedBox(height: 15),
              Text(
                'Confidence: ${confidence}%',
                style: TextStyle(color: AppTheme.holoBlue),
              ),
            ],
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

  Future<void> _addToCollection() async {
    final result = _identificationResult;
    if (result == null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save crystals to your collection.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final identification =
          (result['identification'] as Map<String, dynamic>?) ?? {};
      final structured =
          (result['structured_data'] as Map<String, dynamic>?) ?? {};
      final metaphysical =
          (structured['metaphysical_properties'] as Map<String, dynamic>?) ??
              (result['metaphysical_properties'] as Map<String, dynamic>?) ??
                  {};
      final colors = List<String>.from(
        (result['colors'] as List?) ??
            (structured['colors'] as List?) ??
            const [],
      );
      final geological = (structured['geological_data'] as Map<String, dynamic>?) ??
          (result['geological_data'] as Map<String, dynamic>?) ?? {};
      final report = result['report'];

      final normalizedMetaphysical = {
        ...metaphysical,
        'elements': _normalizeElements(
          metaphysical['elements'],
          metaphysical['element'],
        ),
      };

      final data = <String, dynamic>{
        'name': identification['name'] ??
            structured['crystal_type'] ??
            'Unknown Crystal',
        'confidence': identification['confidence'],
        'variety': identification['variety'],
        'description': result['description'] ?? report,
        'report': report,
        'imageUrl': result['imageUrl'],
        'metaphysicalProperties': normalizedMetaphysical,
        'healingProperties':
            _asStringList(metaphysical['healing_properties']),
        'primaryChakras':
            _asStringList(metaphysical['primary_chakras']),
        'zodiacSigns':
            _asStringList(metaphysical['zodiac_signs']),
        'elements': _normalizeElements(
          metaphysical['elements'],
          metaphysical['element'],
        ),
        'colors': colors,
        'geologicalData': geological,
        'analysisDate': structured['analysis_date'] ?? result['analysis_date'],
        'structuredData': structured,
        'source': 'identification',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('collection')
          .add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${data['name']} added to your collection.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.amethystPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save crystal: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          const SimpleGradientParticles(particleCount: 5),
          
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
    final identification =
        (crystal['identification'] as Map<String, dynamic>?) ?? {};
    final metaphysical =
        (crystal['metaphysical_properties'] as Map<String, dynamic>?) ?? {};
    final structured =
        (crystal['structured_data'] as Map<String, dynamic>?) ?? {};
    final colors = _mergeStringLists(crystal['colors'], structured['colors']);
    final geological = (crystal['geological_data'] as Map<String, dynamic>?) ??
        (structured['geological_data'] as Map<String, dynamic>?) ?? {};
    final report = crystal['report']?.toString();
    final reportParagraphs = _extractReportParagraphs(report);
    final description = crystal['description']?.toString() ??
        (reportParagraphs.isNotEmpty ? reportParagraphs.first : 'No description available');
    final analysisDate = crystal['analysis_date']?.toString() ??
        structured['analysis_date']?.toString();
    final confidence = identification['confidence'];
    final healingProperties =
        _asStringList(metaphysical['healing_properties']);
    final chakras = _asStringList(metaphysical['primary_chakras']);
    final zodiacSigns = _asStringList(metaphysical['zodiac_signs']);

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

            if (confidence != null) ...[
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
                  'Confidence: ${confidence}%',
                  style: TextStyle(
                    color: AppTheme.holoBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              description,
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),

            if (reportParagraphs.length > 1) ...[
              const SizedBox(height: 20),
              Text(
                '🔮 Mystic Insights',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.holoPink,
                ),
              ),
              const SizedBox(height: 10),
              ...reportParagraphs.skip(1).map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    paragraph,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ),
            ],

            if (colors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '🎨 Color Palette',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mysticPink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: colors
                    .map((shade) => _buildTagChip(shade))
                    .toList(),
              ),
            ],

            if (healingProperties.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '✨ Healing Properties',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.mysticPink,
                ),
              ),
              const SizedBox(height: 10),
              ...healingProperties.map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      const Text('• ', style: TextStyle(color: AppTheme.crystalGlow)),
                      Expanded(
                        child: Text(
                          property,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (chakras.isNotEmpty) ...[
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
                children: chakras
                    .map((chakra) => _buildTagChip(chakra))
                    .toList(),
              ),
            ],

            if (zodiacSigns.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(
                '♈ Zodiac Harmony',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mysticPink,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: zodiacSigns
                    .map((sign) => _buildTagChip(sign))
                    .toList(),
              ),
            ],

            if (metaphysical['element'] != null) ...[
              const SizedBox(height: 15),
              _buildInfoRow('Elemental Alignment', metaphysical['element'].toString()),
            ],

            if (geological != null && geological.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '🪨 Geological Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mysticPink,
                ),
              ),
              const SizedBox(height: 8),
              if (geological['mohs_hardness'] != null)
                _buildInfoRow('Mohs Hardness', geological['mohs_hardness'].toString()),
              if (geological['chemical_formula'] != null)
                _buildInfoRow('Chemical Formula', geological['chemical_formula'].toString()),
            ],

            if (analysisDate != null) ...[
              const SizedBox(height: 10),
              _buildInfoRow('Analysis Date', analysisDate),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return [];
  }

  List<String> _mergeStringLists(dynamic first, dynamic second) {
    final combined = <String>{};
    combined.addAll(_asStringList(first));
    combined.addAll(_asStringList(second));
    return combined.toList();
  }

  List<String> _normalizeElements(dynamic elements, dynamic elementValue) {
    final normalized = <String>{};
    normalized.addAll(_asStringList(elements));
    normalized.addAll(_asStringList(elementValue));
    return normalized.toList();
  }

  List<String> _extractReportParagraphs(String? report) {
    if (report == null || report.trim().isEmpty) {
      return [];
    }
    final cleaned = report
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\*{1,2}([^*]+)\*{1,2}'), r'$1');
    return cleaned
        .split(RegExp(r'\n{1,2}'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: AppTheme.cosmicPurple.withOpacity(0.3),
        border: Border.all(color: AppTheme.cosmicPurple.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.crystalGlow,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.crystalGlow,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}