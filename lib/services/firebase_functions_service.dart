import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Firebase Cloud Functions service for Crystal Grimoire V3
/// Connects Flutter app to serverless Firebase Functions backend
class FirebaseFunctionsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  /// Initialize Firebase Functions
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    // Use emulator if in debug mode
    // if (kDebugMode) {
    //   _functions.useFunctionsEmulator('localhost', 5001);
    // }
  }

  /// Identify crystal using AI with personalized context
  /// 
  /// [imageData] - Base64 encoded image data
  /// [userId] - User ID for personalization
  /// Returns complete crystal data with metaphysical properties
  static Future<Map<String, dynamic>> identifyCrystal({
    required String imageData,
    String? userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('identifyCrystal');
      final result = await callable.call({
        'imageData': imageData,
        'userId': userId,
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to identify crystal: $e');
    }
  }

  /// Get current moon phase
  static Future<Map<String, dynamic>> getCurrentMoonPhase() async {
    try {
      final callable = _functions.httpsCallable('getCurrentMoonPhase');
      final result = await callable.call();
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get moon phase: $e');
    }
  }

  /// Get personalized moon ritual for specific phase
  /// 
  /// [phase] - Moon phase (new, full, first_quarter, last_quarter)
  /// [userId] - User ID for crystal collection personalization
  static Future<Map<String, dynamic>> getMoonRitual({
    required String phase,
    String? userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getMoonRitual');
      final result = await callable.call({
        'phase': phase,
        'userId': userId,
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get moon ritual: $e');
    }
  }

  /// Create dream journal entry with AI analysis
  /// 
  /// [userId] - User ID
  /// [dreamContent] - Dream description text
  /// [crystalsPresent] - List of crystals present during dream
  /// [dreamDate] - Date of dream (optional, defaults to now)
  /// [additionalData] - Any additional metadata
  static Future<Map<String, dynamic>> createDreamEntry({
    required String userId,
    required String dreamContent,
    List<String>? crystalsPresent,
    DateTime? dreamDate,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final callable = _functions.httpsCallable('createDreamEntry');
      final result = await callable.call({
        'userId': userId,
        'dreamContent': dreamContent,
        'crystalsPresent': crystalsPresent ?? [],
        'dreamDate': dreamDate?.toIso8601String(),
        'additionalData': additionalData ?? {},
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to create dream entry: $e');
    }
  }

  /// Update user profile data
  /// 
  /// [userId] - User ID
  /// [profileData] - Profile data including birth chart, preferences, etc.
  static Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateUserProfile');
      final result = await callable.call({
        'userId': userId,
        'profileData': profileData,
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Get personalized spiritual guidance using birth chart + crystal collection
  /// 
  /// [userId] - User ID
  /// [query] - User's question or guidance request
  /// [contextType] - Type of guidance (general, healing, ritual, etc.)
  static Future<Map<String, dynamic>> getPersonalizedGuidance({
    required String userId,
    required String query,
    String contextType = 'general',
  }) async {
    try {
      final callable = _functions.httpsCallable('getPersonalizedGuidance');
      final result = await callable.call({
        'userId': userId,
        'query': query,
        'contextType': contextType,
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get personalized guidance: $e');
    }
  }

  /// Helper method to convert image to base64
  static String imageToBase64(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  /// Helper method to handle errors consistently
  static String _handleError(dynamic error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'User must be logged in to use this feature';
        case 'permission-denied':
          return 'Permission denied. Please check your account status';
        case 'invalid-argument':
          return 'Invalid request. Please check your input';
        case 'not-found':
          return 'Requested resource not found';
        case 'internal':
          return 'Internal server error. Please try again later';
        default:
          return 'Error: ${error.message}';
      }
    }
    return 'Unexpected error occurred: $error';
  }
}