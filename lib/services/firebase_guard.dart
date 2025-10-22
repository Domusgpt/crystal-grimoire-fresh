import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Provides safe access to Firebase services when the SDK has been configured.
class FirebaseGuard {
  FirebaseGuard._();

  /// Returns true when a Firebase app has been initialized.
  static bool get isConfigured {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the default [FirebaseAuth] instance when available.
  static FirebaseAuth? get auth {
    if (!isConfigured) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Returns the default [FirebaseFirestore] instance when available.
  static FirebaseFirestore? get firestore {
    if (!isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Returns the default [FirebaseFunctions] instance when available.
  static FirebaseFunctions? functions({String? region}) {
    if (!isConfigured) return null;
    try {
      if (region == null) {
        return FirebaseFunctions.instance;
      }
      return FirebaseFunctions.instanceFor(region: region);
    } catch (_) {
      return null;
    }
  }
}
