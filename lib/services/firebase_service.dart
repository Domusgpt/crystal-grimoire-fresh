import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/crystal_model.dart';
import '../models/user_profile_model.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // User profile
  UserProfile? _currentUserProfile;
  UserProfile? get currentUserProfile => _currentUserProfile;
  
  // Crystal database
  List<Crystal> _crystalDatabase = [];
  List<Crystal> get crystalDatabase => _crystalDatabase;
  
  // User's crystal collection
  List<Crystal> _userCollection = [];
  List<Crystal> get userCollection => _userCollection;
  
  // Initialize service
  Future<void> initialize() async {
    try {
      // Load crystal database
      await loadCrystalDatabase();
      
      // Listen to auth changes
      _auth.authStateChanges().listen((User? user) {
        if (user != null) {
          loadUserProfile(user.uid);
          loadUserCollection(user.uid);
        } else {
          _currentUserProfile = null;
          _userCollection = [];
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }
  
  // Load master crystal database
  Future<void> loadCrystalDatabase() async {
    try {
      final snapshot = await _firestore
          .collection('crystal_database')
          .orderBy('name')
          .get();
      
      _crystalDatabase = snapshot.docs
          .map((doc) => Crystal.fromFirestore(doc))
          .toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading crystal database: $e');
    }
  }
  
  // Load user profile
  Future<void> loadUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        _currentUserProfile = UserProfile.fromFirestore(doc);
        notifyListeners();
      } else {
        // Create new profile
        await createUserProfile(userId);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }
  
  // Create user profile
  Future<void> createUserProfile(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final profile = UserProfile(
        uid: userId,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Crystal Seeker',
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        subscriptionTier: 'free',
        dailyCredits: 3,
        birthChart: {},
        preferences: {
          'theme': 'dark',
          'notifications': true,
          'dailyCrystal': true,
        },
      );
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set(profile.toMap());
      
      _currentUserProfile = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating user profile: $e');
    }
  }
  
  // Load user's crystal collection
  Future<void> loadUserCollection(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('crystals')
          .orderBy('acquisitionDate', descending: true)
          .get();
      
      _userCollection = snapshot.docs
          .map((doc) => Crystal.fromFirestore(doc))
          .toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user collection: $e');
    }
  }
  
  // Add crystal to user collection
  Future<void> addToCollection(Crystal crystal) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      crystal.acquisitionDate = DateTime.now();
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('crystals')
          .doc(crystal.id)
          .set(crystal.toMap());
      
      _userCollection.add(crystal);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding crystal to collection: $e');
    }
  }
  
  // Save crystal identification
  Future<void> saveCrystalIdentification({
    required String imageUrl,
    required Map<String, dynamic> identificationData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore.collection('identifications').add({
        'userId': user.uid,
        'imageUrl': imageUrl,
        'identificationData': identificationData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving identification: $e');
    }
  }
  
  // Save dream journal entry
  Future<void> saveDreamEntry({
    required String title,
    required String content,
    List<String>? crystalsUsed,
    Map<String, dynamic>? analysis,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dreams')
          .add({
        'title': title,
        'content': content,
        'crystalsUsed': crystalsUsed ?? [],
        'analysis': analysis ?? {},
        'date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving dream entry: $e');
    }
  }
  
  // Get moon phase data
  Future<Map<String, dynamic>> getMoonPhaseData() async {
    try {
      final doc = await _firestore
          .collection('moon_data')
          .doc('current')
          .get();
      
      if (doc.exists) {
        return doc.data() ?? {};
      }
      
      // Calculate moon phase if not in database
      return calculateMoonPhase();
    } catch (e) {
      debugPrint('Error getting moon phase: $e');
      return calculateMoonPhase();
    }
  }
  
  // Calculate current moon phase
  Map<String, dynamic> calculateMoonPhase() {
    final now = DateTime.now();
    final knownNewMoon = DateTime(2024, 1, 11); // Known new moon date
    final lunarCycle = 29.53059; // Days in lunar cycle
    
    final daysSince = now.difference(knownNewMoon).inDays;
    final currentPhase = (daysSince % lunarCycle) / lunarCycle;
    
    String phaseName;
    String emoji;
    
    if (currentPhase < 0.0625) {
      phaseName = 'New Moon';
      emoji = '🌑';
    } else if (currentPhase < 0.1875) {
      phaseName = 'Waxing Crescent';
      emoji = '🌒';
    } else if (currentPhase < 0.3125) {
      phaseName = 'First Quarter';
      emoji = '🌓';
    } else if (currentPhase < 0.4375) {
      phaseName = 'Waxing Gibbous';
      emoji = '🌔';
    } else if (currentPhase < 0.5625) {
      phaseName = 'Full Moon';
      emoji = '🌕';
    } else if (currentPhase < 0.6875) {
      phaseName = 'Waning Gibbous';
      emoji = '🌖';
    } else if (currentPhase < 0.8125) {
      phaseName = 'Last Quarter';
      emoji = '🌗';
    } else {
      phaseName = 'Waning Crescent';
      emoji = '🌘';
    }
    
    return {
      'phase': phaseName,
      'emoji': emoji,
      'illumination': (0.5 * (1 + (currentPhase < 0.5 
          ? currentPhase * 2 
          : 2 - currentPhase * 2))),
      'nextFullMoon': calculateNextPhase(now, 0.5, lunarCycle, daysSince),
      'nextNewMoon': calculateNextPhase(now, 0.0, lunarCycle, daysSince),
    };
  }
  
  DateTime calculateNextPhase(DateTime now, double targetPhase, 
      double cycle, int daysSince) {
    final currentPhase = (daysSince % cycle) / cycle;
    final daysToTarget = targetPhase > currentPhase
        ? (targetPhase - currentPhase) * cycle
        : (1 - currentPhase + targetPhase) * cycle;
    return now.add(Duration(days: daysToTarget.round()));
  }
  
  // Upload image to Firebase Storage
  Future<String?> uploadImage(String path, List<int> imageBytes) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final ref = _storage.ref().child('users/${user.uid}/$path');
      final uploadTask = await ref.putData(
        Uint8List.fromList(imageBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
  
  // Get daily crystal recommendation
  Future<Crystal?> getDailyCrystal() async {
    try {
      final user = _auth.currentUser;
      if (user == null || _crystalDatabase.isEmpty) return null;
      
      // Use user's birth chart for personalized selection
      if (_currentUserProfile?.birthChart != null) {
        final sunSign = _currentUserProfile!.birthChart['sunSign'];
        // Filter crystals by zodiac compatibility
        final compatible = _crystalDatabase.where((c) =>
          c.metaphysicalProperties['zodiacSigns']?.contains(sunSign) ?? false
        ).toList();
        
        if (compatible.isNotEmpty) {
          final today = DateTime.now().day;
          return compatible[today % compatible.length];
        }
      }
      
      // Default to date-based selection
      final today = DateTime.now().day;
      return _crystalDatabase[today % _crystalDatabase.length];
    } catch (e) {
      debugPrint('Error getting daily crystal: $e');
      return null;
    }
  }
  
  // Save healing session
  Future<void> saveHealingSession({
    required List<String> crystalIds,
    required List<String> chakras,
    required int duration,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('healing_sessions')
          .add({
        'crystalIds': crystalIds,
        'chakras': chakras,
        'duration': duration,
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving healing session: $e');
    }
  }
}