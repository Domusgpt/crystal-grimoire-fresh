import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import '../services/economy_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<Map<String, dynamic>> _userCrystals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserCollection();
  }

  Future<void> _loadUserCollection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final collectionSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('collection')
            .orderBy('addedAt', descending: true)
            .get();

        final crystals = <Map<String, dynamic>>[];
        for (final doc in collectionSnapshot.docs) {
          final crystalData = doc.data();
          // Get crystal details from library
          if (crystalData['libraryRef'] != null) {
            final libraryDoc = await FirebaseFirestore.instance
                .doc(crystalData['libraryRef'])
                .get();
            if (libraryDoc.exists) {
              crystals.add({
                'id': doc.id,
                'personalNotes': crystalData['notes'],
                'tags': crystalData['tags'],
                'addedAt': crystalData['addedAt'],
                ...libraryDoc.data()!,
              });
            }
          }
        }

        setState(() {
          _userCrystals = crystals;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Please sign in to view your collection';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading collection: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepMystical,
              AppTheme.mysticalPurple,
              AppTheme.deepMystical,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '🔮 My Crystal Collection',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Collection Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildCollectionContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionContent() {
    if (_isLoading) {
      return const GlassmorphicContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.crystalGlow),
              SizedBox(height: 20),
              Text(
                'Loading your crystal collection...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return GlassmorphicContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadUserCollection();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.crystalGlow,
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    if (_userCrystals.isEmpty) {
      return GlassmorphicContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.diamond_outlined,
                color: AppTheme.crystalGlow,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your crystal collection is empty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Start by identifying crystals to add them to your collection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.crystalGlow,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text(
                  'Go Identify Crystals',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassmorphicContainer(
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: _userCrystals.length,
        itemBuilder: (context, index) {
          final crystal = _userCrystals[index];
          return _buildCrystalCard(crystal);
        },
      ),
    );
  }

  Widget _buildCrystalCard(Map<String, dynamic> crystal) {
    return GlassmorphicContainer(
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Crystal icon/image placeholder
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.crystalGlow.withOpacity(0.3),
                    AppTheme.amethystPurple.withOpacity(0.2),
                  ],
                ),
              ),
              child: const Icon(
                Icons.diamond,
                size: 40,
                color: AppTheme.crystalGlow,
              ),
            ),
            const SizedBox(height: 10),
            // Crystal name
            Text(
              crystal['name'] ?? 'Unknown Crystal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            // Crystal intents
            if (crystal['intents'] != null && crystal['intents'].isNotEmpty)
              Text(
                crystal['intents'].take(2).join(', '),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            // Personal notes indicator
            if (crystal['personalNotes'] != null && crystal['personalNotes'].isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.crystalGlow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Has Notes',
                  style: TextStyle(
                    color: AppTheme.crystalGlow,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}