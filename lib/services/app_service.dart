import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_guard.dart';

/// Unified app service using standard Firebase SDK
/// Replaces the heavyweight custom implementation
class AppService extends ChangeNotifier {
  static AppService? _instance;
  static AppService get instance => _instance ??= AppService._();
  
  AppService._();
  
  // Firebase instances - lazy loaded for performance
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseFunctions? _functions;

  bool get _hasFirebase => FirebaseGuard.isConfigured;

  // Getters with lazy initialization
  FirebaseAuth? get auth => _auth ??= FirebaseGuard.auth;
  FirebaseFirestore? get firestore => _firestore ??= FirebaseGuard.firestore;
  FirebaseFunctions? get functions => _functions ??= FirebaseGuard.functions();

  // Current user state
  User? get currentUser => auth?.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get firebaseAvailable => auth != null && firestore != null;
  
  // Initialization state
  bool _isInitialized = false;
  String? _lastError;
  
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  
  // Auth state stream
  Stream<User?> get authStateChanges =>
      auth?.authStateChanges() ?? const Stream<User?>.empty();
  
  /// Initialize app services (async, non-blocking)
  Future<void> initialize() async {
    try {
      _lastError = null;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_hasFirebase) {
        _lastError =
            'Firebase services are not configured. Running in offline preview mode.';
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('App service initialization failed: $e');
      _lastError = 'Failed to initialize: $e';
      _isInitialized = false;
      notifyListeners();
      // Don't throw - app should still work
    }
  }
  
  /// Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    final firebaseAuth = auth;
    if (firebaseAuth == null) {
      _lastError = 'Firebase authentication is not configured.';
      notifyListeners();
      return null;
    }

    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      return null;
    }
  }
  
  /// Register new user
  Future<UserCredential?> register(String email, String password, String name) async {
    final firebaseAuth = auth;
    final store = firestore;
    if (firebaseAuth == null || store == null) {
      _lastError = 'Firebase is not configured. Unable to register.';
      notifyListeners();
      return null;
    }

    try {
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(name);
      
      // Create user document
      await store.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Registration failed: $e');
      return null;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    final firebaseAuth = auth;
    if (firebaseAuth == null) {
      _lastError = 'Firebase authentication is not configured.';
      notifyListeners();
      return;
    }

    try {
      await firebaseAuth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }
  
  /// Get user document
  Future<DocumentSnapshot?> getUserDocument([String? uid]) async {
    try {
      final userId = uid ?? currentUser?.uid;
      final store = firestore;
      if (userId == null || store == null) return null;

      return await store.collection('users').doc(userId).get();
    } catch (e) {
      debugPrint('Failed to get user document: $e');
      return null;
    }
  }
  
  /// Get user collection
  Future<QuerySnapshot?> getUserCollection([String? uid]) async {
    try {
      final userId = uid ?? currentUser?.uid;
      final store = firestore;
      if (userId == null || store == null) return null;

      return await store
          .collection('users')
          .doc(userId)
          .collection('collection')
          .orderBy('addedAt', descending: true)
          .get();
    } catch (e) {
      debugPrint('Failed to get user collection: $e');
      return null;
    }
  }
  
  /// Call cloud function
  Future<Map<String, dynamic>?> callFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final callable = functions?.httpsCallable(functionName);
    if (callable == null) {
      _lastError = 'Firebase Functions are not configured.';
      notifyListeners();
      return null;
    }

    try {
      final result = await callable.call(data);
      return result.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Cloud function call failed ($functionName): $e');
      return null;
    }
  }
  
  /// Stream user document
  Stream<DocumentSnapshot> getUserDocumentStream([String? uid]) {
    final userId = uid ?? currentUser?.uid;
    final store = firestore;
    if (userId == null || store == null) {
      return Stream.error('User not authenticated');
    }

    return store.collection('users').doc(userId).snapshots();
  }
  
  /// Stream user collection
  Stream<QuerySnapshot> getUserCollectionStream([String? uid]) {
    final userId = uid ?? currentUser?.uid;
    final store = firestore;
    if (userId == null || store == null) {
      return Stream.error('User not authenticated');
    }

    return store
        .collection('users')
        .doc(userId)
        .collection('collection')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }
  
  /// Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    final store = firestore;
    try {
      final userId = currentUser?.uid;
      if (userId == null || store == null) return false;

      await store.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      return false;
    }
  }
  
  /// Add to user collection
  Future<bool> addToCollection(Map<String, dynamic> crystalData) async {
    final store = firestore;
    try {
      final userId = currentUser?.uid;
      if (userId == null || store == null) return false;

      await store
          .collection('users')
          .doc(userId)
          .collection('collection')
          .add({
        ...crystalData,
        'addedAt': FieldValue.serverTimestamp(),
      });
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to add to collection: $e');
      return false;
    }
  }
}