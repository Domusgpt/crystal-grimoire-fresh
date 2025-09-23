import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

/// Lightweight facade that routes crystal identification requests through the
/// deployed Firebase Cloud Functions.
///
/// The original implementation depended on the `firebase_ai` package which is
/// not referenced in `pubspec.yaml`. That broke the build even when the service
/// was unused. This version keeps the same public surface while delegating to
/// callable Functions so the app can compile without additional plugins.
class FirebaseAIService {
  FirebaseAIService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Identify a crystal based on image bytes. Returns the structured response
  /// produced by the `identifyCrystal` callable Function.
  static Future<Map<String, dynamic>> identifyCrystal({
    required Uint8List imageBytes,
    String? userQuery,
    Map<String, dynamic>? userContext,
  }) async {
    try {
      final callable = _functions.httpsCallable('identifyCrystal');
      final response = await callable.call({
        'imageData': base64Encode(imageBytes),
        if (userQuery != null && userQuery.trim().isNotEmpty)
          'userQuery': userQuery.trim(),
        if (userContext != null && userContext.isNotEmpty)
          'userContext': userContext,
        'includeMetaphysical': true,
        'includeHealing': true,
        'includeCare': true,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      return {
        'error': error.message ?? error.code,
        'fallback_name': 'Unknown Crystal',
        'confidence': 0,
        'processed_at': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      return {
        'error': error.toString(),
        'fallback_name': 'Unknown Crystal',
        'confidence': 0,
        'processed_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Generate spiritual guidance based on a question and optional user profile
  /// details. Delegates to `getCrystalGuidance`.
  static Future<String> generateSpritualGuidance({
    required String query,
    Map<String, dynamic>? userProfile,
    List<String>? ownedCrystals,
  }) async {
    try {
      final callable = _functions.httpsCallable('getCrystalGuidance');
      final response = await callable.call({
        'question': query,
        if (userProfile != null && userProfile.isNotEmpty)
          'userProfile': userProfile,
        if (ownedCrystals != null && ownedCrystals.isNotEmpty)
          'ownedCrystals': ownedCrystals,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return data['guidance']?.toString() ??
          'Guidance is not available at the moment.';
    } catch (error) {
      return 'I\'m unable to provide guidance right now. Please try again soon.';
    }
  }
}
