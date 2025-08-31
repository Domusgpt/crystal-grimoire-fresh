import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }
  
  // Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _currentUser = credential.user;
      await _updateLastActive();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Register with email and password
  Future<bool> registerWithEmail(String email, String password, String displayName) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await _createUserProfile(credential.user!);
      }
      
      _currentUser = credential.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (!userDoc.exists) {
          await _createUserProfile(userCredential.user!);
        } else {
          await _updateLastActive();
        }
      }
      
      _currentUser = userCredential.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign in with Google: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
  
  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      await _auth.sendPasswordResetEmail(email: email);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      final profile = {
        'email': user.email,
        'displayName': user.displayName ?? 'Crystal Seeker',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'subscriptionTier': 'free',
        'dailyCredits': 3,
        'totalCredits': 0,
        'birthChart': {},
        'preferences': {
          'theme': 'dark',
          'notifications': true,
          'dailyCrystal': true,
          'moonPhaseAlerts': true,
        },
        'favoriteCategories': [],
        'ownedCrystalIds': [],
        'stats': {
          'crystalsIdentified': 0,
          'collectionsSize': 0,
          'healingSessions': 0,
          'meditationMinutes': 0,
          'journalEntries': 0,
          'ritualsCompleted': 0,
        },
      };
      
      await _firestore.collection('users').doc(user.uid).set(profile);
      
      // Send welcome notification
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': 'Welcome to Crystal Grimoire! 🔮',
        'message': 'Your mystical journey begins now. Explore your first crystal today!',
        'type': 'welcome',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating user profile: $e');
    }
  }
  
  // Update last active timestamp
  Future<void> _updateLastActive() async {
    if (_currentUser != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'lastActive': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('Error updating last active: $e');
      }
    }
  }
  
  // Get error message
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
  
  // Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;
  
  // Get user ID
  String? get userId => _currentUser?.uid;
  
  // Get user email
  String? get userEmail => _currentUser?.email;
  
  // Get user display name
  String? get userDisplayName => _currentUser?.displayName;
  
  // Get user photo URL
  String? get userPhotoUrl => _currentUser?.photoURL;
}