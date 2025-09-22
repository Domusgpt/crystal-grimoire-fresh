import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EconomyService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Current user's economy data
  int _seerCredits = 0;
  int _lifetimeCreditsEarned = 0;
  Map<String, int> _dailyEarnLimits = {};
  Map<String, int> _dailyEarnCount = {};
  
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  int get seerCredits => _seerCredits;
  int get lifetimeCreditsEarned => _lifetimeCreditsEarned;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Economy constants from SPEC-1
  static const Map<String, int> earnRates = {
    'onboarding_complete': 3,
    'daily_checkin': 2,
    'share_card': 1, // max 3/week
    'meditation_complete': 1, // max 1/day
    'crystal_identify_new': 1, // capped per day
    'journal_entry': 1, // max 1/day
    'ritual_complete': 1, // max 1/day
  };

  static const Map<String, int> spendRates = {
    'extra_identify': 1,
    'extra_guidance': 1,
    'priority_queue': 2, // future feature
    'theme_unlock': 5, // future feature
  };

  static const Map<String, int> dailyLimits = {
    'share_card': 3, // per week, but tracked daily
    'meditation_complete': 1,
    'crystal_identify_new': 3, // generous daily limit
    'journal_entry': 1,
    'ritual_complete': 1,
  };

  /// Initialize economy for user
  Future<void> initializeForUser(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Get or create user economy document
      final economyRef = _firestore.collection('users').doc(userId).collection('economy').doc('credits');
      final economySnapshot = await economyRef.get();

      if (economySnapshot.exists) {
        final data = economySnapshot.data()!;
        _seerCredits = data['credits'] ?? 0;
        _lifetimeCreditsEarned = data['lifetimeEarned'] ?? 0;
        _dailyEarnCount = Map<String, int>.from(data['dailyEarnCount'] ?? {});
        _dailyEarnLimits = Map<String, int>.from(data['dailyLimits'] ?? dailyLimits);
      } else {
        // Initialize new user economy
        await _initializeNewUserEconomy(userId, economyRef);
      }

      // Check if daily limits need reset (new day)
      await _checkDailyReset(userId, economyRef);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize economy: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize economy for new user
  Future<void> _initializeNewUserEconomy(String userId, DocumentReference economyRef) async {
    _seerCredits = 0;
    _lifetimeCreditsEarned = 0;
    _dailyEarnCount = {};
    _dailyEarnLimits = Map<String, int>.from(dailyLimits);

    await economyRef.set({
      'credits': _seerCredits,
      'lifetimeEarned': _lifetimeCreditsEarned,
      'dailyEarnCount': _dailyEarnCount,
      'dailyLimits': _dailyEarnLimits,
      'lastResetDate': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check and reset daily limits if new day
  Future<void> _checkDailyReset(String userId, DocumentReference economyRef) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final economySnapshot = await economyRef.get();
    
    if (economySnapshot.exists) {
      final data = economySnapshot.data()! as Map<String, dynamic>;
      final lastResetDate = data['lastResetDate'] as String?;
      
      if (lastResetDate != today) {
        // Reset daily counters for new day
        _dailyEarnCount = {};
        
        await economyRef.update({
          'dailyEarnCount': {},
          'lastResetDate': today,
        });
      }
    }
  }

  /// Earn Seer Credits with validation
  Future<bool> earnCredits({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validate earn rate exists
      if (!earnRates.containsKey(action)) {
        _errorMessage = 'Invalid earn action: $action';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check daily limit
      final limit = dailyLimits[action];
      if (limit != null) {
        final currentCount = _dailyEarnCount[action] ?? 0;
        if (currentCount >= limit) {
          _errorMessage = 'Daily limit reached for $action';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Calculate credits to earn
      final creditsToEarn = earnRates[action]!;

      // Use Cloud Function for server-side validation and atomic update
      final callable = _functions.httpsCallable('earnSeerCredits');
      final result = await callable.call({
        'action': action,
        'creditsToEarn': creditsToEarn,
        'metadata': metadata ?? {},
      });

      final success = result.data['success'] as bool;
      
      if (success) {
        // Update local state
        _seerCredits = result.data['newCredits'] as int;
        _lifetimeCreditsEarned = result.data['lifetimeEarned'] as int;
        _dailyEarnCount[action] = (_dailyEarnCount[action] ?? 0) + 1;

        // Create earn transaction record
        await _recordTransaction(
          userId: userId,
          type: 'earn',
          action: action,
          amount: creditsToEarn,
          metadata: metadata,
        );

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.data['error'] as String? ?? 'Unknown error';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to earn credits: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Spend Seer Credits with validation
  Future<bool> spendCredits({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validate spend rate exists
      if (!spendRates.containsKey(action)) {
        _errorMessage = 'Invalid spend action: $action';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final creditsToSpend = spendRates[action]!;

      // Check if user has enough credits
      if (_seerCredits < creditsToSpend) {
        _errorMessage = 'Insufficient Seer Credits. Need $creditsToSpend, have $_seerCredits';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Use Cloud Function for server-side validation and atomic update
      final callable = _functions.httpsCallable('spendSeerCredits');
      final result = await callable.call({
        'action': action,
        'creditsToSpend': creditsToSpend,
        'metadata': metadata ?? {},
      });

      final success = result.data['success'] as bool;
      
      if (success) {
        // Update local state
        _seerCredits = result.data['newCredits'] as int;

        // Create spend transaction record
        await _recordTransaction(
          userId: userId,
          type: 'spend',
          action: action,
          amount: -creditsToSpend, // Negative for spending
          metadata: metadata,
        );

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.data['error'] as String? ?? 'Unknown error';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to spend credits: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Record transaction for audit trail
  Future<void> _recordTransaction({
    required String userId,
    required String type,
    required String action,
    required int amount,
    Map<String, dynamic>? metadata,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add({
      'type': type, // 'earn' or 'spend'
      'action': action,
      'amount': amount,
      'balanceAfter': _seerCredits,
      'metadata': metadata ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get user's transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory(String userId, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting transaction history: $e');
      return [];
    }
  }

  /// Check if user can earn more credits for a specific action today
  bool canEarnForAction(String action) {
    final limit = dailyLimits[action];
    if (limit == null) return true; // No daily limit
    
    final currentCount = _dailyEarnCount[action] ?? 0;
    return currentCount < limit;
  }

  /// Get remaining earn opportunities for today
  Map<String, int> getRemainingEarnOpportunities() {
    final remaining = <String, int>{};
    
    for (final action in dailyLimits.keys) {
      final limit = dailyLimits[action]!;
      final used = _dailyEarnCount[action] ?? 0;
      remaining[action] = (limit - used).clamp(0, limit);
    }
    
    return remaining;
  }

  /// Get formatted display of earn/spend rates
  static Map<String, String> getEarnDisplayInfo() {
    return {
      'onboarding_complete': '🎉 Complete onboarding: +3 SC (one-time)',
      'daily_checkin': '☀️ Daily check-in: +2 SC',
      'share_card': '📱 Share guidance card: +1 SC (max 3/week)',
      'meditation_complete': '🧘 Complete meditation: +1 SC (daily)',
      'crystal_identify_new': '🔍 Identify new crystal: +1 SC (limited daily)',
      'journal_entry': '📖 Write journal entry: +1 SC (daily)',
      'ritual_complete': '🌙 Complete ritual: +1 SC (daily)',
    };
  }

  static Map<String, String> getSpendDisplayInfo() {
    return {
      'extra_identify': '🔍 Extra identification: 1 SC',
      'extra_guidance': '✨ Extra guidance: 1 SC',
      'priority_queue': '⚡ Priority processing: 2 SC (roadmap perk)',
      'theme_unlock': '🎨 Unlock theme: 5 SC (roadmap perk)',
    };
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}