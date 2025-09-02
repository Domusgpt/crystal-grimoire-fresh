import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../models/crystal_collection.dart';
import '../models/journal_entry.dart';

/// Production Firebase Service using official Flutter SDK
/// Provides real-time sync, offline support, and Firebase Extensions integration
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Getters leveraging Firebase SDK
  bool get isAuthenticated => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;
  
  /// Real-time user profile stream (replaces REST polling)
  Stream<UserProfile?> get userProfileStream {
    if (!isAuthenticated) return Stream.value(null);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists 
            ? UserProfile.fromJson(snapshot.data()!) 
            : null);
  }
  
  /// Real-time crystal collection stream with offline support
  Stream<List<CrystalCollection>> get crystalCollectionStream {
    if (!isAuthenticated) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('crystals')
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CrystalCollection.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
  
  /// Firebase Auth SDK registration (replaces REST auth)
  Future<UserProfile> registerUser({
    required String email,
    required String password,
    required String name,
    DateTime? birthDate,
    String? birthTime,
    String? birthLocation,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Update display name
    await credential.user!.updateDisplayName(name);
    
    // Create user profile document
    final userProfile = UserProfile(
      id: credential.user!.uid,
      email: email,
      name: name,
      birthDate: birthDate,
      birthTime: birthTime,
      birthLocation: birthLocation,
      subscriptionTier: 'free',
      createdAt: DateTime.now(),
    );
    
    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(userProfile.toJson());
    
    return userProfile;
  }
  
  /// Firebase Auth SDK login (replaces REST auth)
  Future<UserProfile> loginUser({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    
    return UserProfile.fromJson(userDoc.data()!);
  }
  
  /// Upload crystal image to Firebase Storage (triggers AI Logic extension)
  Future<String> uploadCrystalImage(List<int> imageBytes, String fileName) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    // Upload to trigger Firebase AI Logic extension
    final ref = _storage.ref('crystal_uploads/$currentUserId/$fileName');
    final uploadTask = await ref.putData(Uint8List.fromList(imageBytes));
    
    return await uploadTask.ref.getDownloadURL();
  }
  
  /// Use Cloud Functions instead of custom backend
  Future<Map<String, dynamic>> identifyCrystal({
    required String imageUrl,
    Map<String, dynamic>? userContext,
  }) async {
    final callable = _functions.httpsCallable('processCrystalIdentification');
    final result = await callable.call({
      'imageUrl': imageUrl,
      'userContext': userContext,
    });
    
    return Map<String, dynamic>.from(result.data);
  }
  
  /// Real-time crystal identification results stream
  Stream<Map<String, dynamic>?> getCrystalIdentificationStream(String uploadId) {
    return _firestore
        .collection('crystal_identifications')
        .where('uploadId', isEqualTo: uploadId)
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty 
            ? snapshot.docs.first.data() 
            : null);
  }
  
  /// Add crystal to collection with automatic Firestore sync
  Future<void> addCrystalToCollection(CrystalCollection crystal) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('crystals')
        .add(crystal.toJson());
  }
  
  /// Track analytics events (auto-exported to BigQuery via extension)
  Future<void> trackEvent({
    required String eventType,
    Map<String, dynamic>? properties,
  }) async {
    if (!isAuthenticated) return;
    
    final callable = _functions.httpsCallable('trackCustomEvents');
    await callable.call({
      'eventType': eventType,
      'properties': properties ?? {},
    });
  }
  
  /// Send personalized notification (triggers FCM extension)
  Future<void> sendNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (!isAuthenticated) return;
    
    await _firestore.collection('notifications').add({
      'userId': currentUserId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  /// Get subscription tier from custom claims (Auth Custom Claims extension)
  Future<String> getSubscriptionTier() async {
    if (!isAuthenticated) return 'free';
    
    final idTokenResult = await _auth.currentUser!.getIdTokenResult();
    return idTokenResult.claims?['subscription_tier'] ?? 'free';
  }
  
  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}