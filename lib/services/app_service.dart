import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Unified app service using standard Firebase SDK
/// Replaces the heavyweight custom implementation
class AppService extends ChangeNotifier {
  static AppService? _instance;
  static AppService get instance => _instance ??= AppService._();

  AppService._();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseFunctions? _functions;

  bool get hasFirebase => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _authOrNull {
    if (!hasFirebase) return null;
    return _auth ??= FirebaseAuth.instance;
  }

  FirebaseFirestore? get _firestoreOrNull {
    if (!hasFirebase) return null;
    return _firestore ??= FirebaseFirestore.instance;
  }

  FirebaseFunctions? get _functionsOrNull {
    if (!hasFirebase) return null;
    return _functions ??= FirebaseFunctions.instance;
  }

  User? get currentUser => _authOrNull?.currentUser;
  bool get isAuthenticated => currentUser != null;

  bool _isInitialized = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  Stream<User?> get authStateChanges {
    final auth = _authOrNull;
    if (auth == null) {
      return Stream<User?>.value(null);
    }
    return auth.authStateChanges();
  }

  Future<void> initialize() async {
    _lastError = null;

    if (!hasFirebase) {
      _lastError =
          'Firebase is not configured. Running in offline-only preview mode.';
    }

    await Future.delayed(const Duration(milliseconds: 50));
    _isInitialized = true;
    notifyListeners();
  }

  Future<UserCredential?> signIn(String email, String password) async {
    final auth = _requireAuth('Sign-in');
    if (auth == null) return null;

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _clearLastError();
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      _lastError = 'Failed to sign in: $e';
      notifyListeners();
      return null;
    }
  }

  Future<UserCredential?> register(
    String email,
    String password,
    String name,
  ) async {
    final auth = _requireAuth('Registration');
    final firestore = _requireFirestore('Registration');
    if (auth == null || firestore == null) return null;

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      await firestore.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _clearLastError();
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Registration failed: $e');
      _lastError = 'Failed to register: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() async {
    final auth = _requireAuth('Sign-out');
    if (auth == null) return;

    try {
      await auth.signOut();
      _clearLastError();
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out failed: $e');
      _lastError = 'Failed to sign out: $e';
      notifyListeners();
    }
  }

  Future<DocumentSnapshot?> getUserDocument([String? uid]) async {
    final firestore = _requireFirestore('Profile lookup');
    if (firestore == null) return null;

    try {
      final userId = uid ?? currentUser?.uid;
      if (userId == null) return null;

      final snapshot = await firestore.collection('users').doc(userId).get();
      _clearLastError();
      return snapshot;
    } catch (e) {
      debugPrint('Failed to get user document: $e');
      _lastError = 'Failed to load profile: $e';
      notifyListeners();
      return null;
    }
  }

  Future<QuerySnapshot?> getUserCollection([String? uid]) async {
    final firestore = _requireFirestore('Collection sync');
    if (firestore == null) return null;

    try {
      final userId = uid ?? currentUser?.uid;
      if (userId == null) return null;

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('collection')
          .orderBy('addedAt', descending: true)
          .get();
      _clearLastError();
      return snapshot;
    } catch (e) {
      debugPrint('Failed to get user collection: $e');
      _lastError = 'Failed to load collection: $e';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> callFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final functions = _requireFunctions('Cloud Function $functionName');
    if (functions == null) return null;

    try {
      final callable = functions.httpsCallable(functionName);
      final result = await callable.call(data);
      _clearLastError();
      return result.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Cloud function call failed ($functionName): $e');
      _lastError = 'Failed to call $functionName: $e';
      notifyListeners();
      return null;
    }
  }

  Stream<DocumentSnapshot> getUserDocumentStream([String? uid]) {
    final firestore = _requireFirestore('Profile stream');
    if (firestore == null) {
      return Stream.error('Firestore not configured');
    }

    final userId = uid ?? currentUser?.uid;
    if (userId == null) {
      return Stream.error('User not authenticated');
    }

    return firestore.collection('users').doc(userId).snapshots();
  }

  Stream<QuerySnapshot> getUserCollectionStream([String? uid]) {
    final firestore = _requireFirestore('Collection stream');
    if (firestore == null) {
      return Stream.error('Firestore not configured');
    }

    final userId = uid ?? currentUser?.uid;
    if (userId == null) {
      return Stream.error('User not authenticated');
    }

    return firestore
        .collection('users')
        .doc(userId)
        .collection('collection')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    final firestore = _requireFirestore('Profile update');
    if (firestore == null) return false;

    try {
      final userId = currentUser?.uid;
      if (userId == null) return false;

      await firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearLastError();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      _lastError = 'Failed to update profile: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addToCollection(Map<String, dynamic> crystalData) async {
    final firestore = _requireFirestore('Collection update');
    if (firestore == null) return false;

    try {
      final userId = currentUser?.uid;
      if (userId == null) return false;

      await firestore
          .collection('users')
          .doc(userId)
          .collection('collection')
          .add({
        ...crystalData,
        'addedAt': FieldValue.serverTimestamp(),
      });

      _clearLastError();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to add to collection: $e');
      _lastError = 'Failed to add crystal: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCrystal(String docId, Map<String, dynamic> data) async {
    final firestore = _requireFirestore('Collection update');
    if (firestore == null) return false;

    try {
      final userId = currentUser?.uid;
      if (userId == null) return false;

      await firestore
          .collection('users')
          .doc(userId)
          .collection('collection')
          .doc(docId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearLastError();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to update crystal: $e');
      _lastError = 'Failed to update crystal: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCrystal(String docId) async {
    final firestore = _requireFirestore('Collection update');
    if (firestore == null) return false;

    try {
      final userId = currentUser?.uid;
      if (userId == null) return false;

      await firestore
          .collection('users')
          .doc(userId)
          .collection('collection')
          .doc(docId)
          .delete();

      _clearLastError();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to delete crystal: $e');
      _lastError = 'Failed to delete crystal: $e';
      notifyListeners();
      return false;
    }
  }

  FirebaseAuth? _requireAuth(String context) {
    final auth = _authOrNull;
    if (auth == null) {
      _lastError = '$context requires Firebase Auth. Configure Firebase first.';
      notifyListeners();
    }
    return auth;
  }

  FirebaseFirestore? _requireFirestore(String context) {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      _lastError = '$context requires Firestore. Configure Firebase first.';
      notifyListeners();
    }
    return firestore;
  }

  FirebaseFunctions? _requireFunctions(String context) {
    final functions = _functionsOrNull;
    if (functions == null) {
      _lastError = '$context requires Cloud Functions. Configure Firebase first.';
      notifyListeners();
    }
    return functions;
  }

  void _clearLastError() {
    if (_lastError != null) {
      _lastError = null;
    }
  }
}
