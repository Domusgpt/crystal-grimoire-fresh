import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../config/plan_entitlements.dart';
import 'firebase_guard.dart';
import 'storage_service.dart';

/// Snapshot of the user's current subscription plan and usage counters returned
/// by the `getPlanStatus` callable.
class PlanStatusSnapshot {
  PlanStatusSnapshot({
    required this.tier,
    required this.limits,
    required this.dailyUsage,
    required this.lifetimeUsage,
    required this.flags,
    required this.isLifetime,
    this.lastResetDate,
    this.updatedAt,
  });

  final String tier;
  final Map<String, int> limits;
  final Map<String, int> dailyUsage;
  final Map<String, int> lifetimeUsage;
  final List<String> flags;
  final bool isLifetime;
  final DateTime? lastResetDate;
  final DateTime? updatedAt;

  factory PlanStatusSnapshot.fromJson(Map<String, dynamic> json) {
    final tier = PlanEntitlements.normalizeTier(json['tier'] as String?);
    final limitsRaw = json['limits'];
    final usageRaw = json['usage'];

    Map<String, int> _coerceIntMap(dynamic source) {
      if (source is Map) {
        return source.map((key, value) => MapEntry(
              key.toString(),
              int.tryParse(value.toString()) ?? 0,
            ));
      }
      return <String, int>{};
    }

    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      return DateTime.tryParse(value.toString())?.toUtc();
    }

    final dailyUsage = usageRaw is Map ? _coerceIntMap(usageRaw['daily']) : <String, int>{};
    final lifetimeUsage = usageRaw is Map ? _coerceIntMap(usageRaw['lifetime']) : <String, int>{};

    return PlanStatusSnapshot(
      tier: tier,
      limits: _coerceIntMap(limitsRaw),
      dailyUsage: dailyUsage,
      lifetimeUsage: lifetimeUsage,
      flags: _coerceStringList(json['flags']),
      isLifetime: json['lifetime'] == true,
      lastResetDate: usageRaw is Map ? _parseDate(usageRaw['lastResetDate']) : null,
      updatedAt: usageRaw is Map ? _parseDate(usageRaw['updatedAt']) : null,
    );
  }

  factory PlanStatusSnapshot.fallback([String? tier]) {
    final normalized = PlanEntitlements.normalizeTier(tier);
    final details = PlanEntitlements.resolve(normalized);
    return PlanStatusSnapshot(
      tier: details.tier,
      limits: Map<String, int>.from(details.effectiveLimits),
      dailyUsage: <String, int>{},
      lifetimeUsage: <String, int>{},
      flags: List<String>.from(details.flags),
      isLifetime: details.lifetime,
      lastResetDate: null,
      updatedAt: null,
    );
  }

  static List<String> _coerceStringList(dynamic value) {
    if (value is List) {
      return value.map((element) => element.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  int limitFor(String limitKey) {
    return limits[limitKey] ?? -1;
  }

  int usageFor(String usageKey) {
    return dailyUsage[usageKey] ?? 0;
  }

  int lifetimeUsageFor(String usageKey) {
    return lifetimeUsage[usageKey] ?? 0;
  }

  bool hasUnlimitedLimit(String limitKey) {
    final limit = limitFor(limitKey);
    return limit <= 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'limits': limits,
      'usage': {
        'daily': dailyUsage,
        'lifetime': lifetimeUsage,
        'lastResetDate': lastResetDate?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      },
      'flags': flags,
      'lifetime': isLifetime,
    };
  }
}

/// Loads and caches plan status information from Cloud Functions with offline
/// persistence in [StorageService].
class PlanStatusService {
  static PlanStatusSnapshot? _cached;
  static DateTime? _lastFetch;

  static bool get _canCallFirebase =>
      FirebaseGuard.isConfigured && FirebaseGuard.functions() != null;

  static Future<PlanStatusSnapshot> getPlanStatus({
    bool forceRefresh = false,
  }) async {
    if (_cached == null) {
      final stored = await StorageService.getPlanStatus();
      if (stored != null) {
        _cached = PlanStatusSnapshot.fromJson(stored);
        if (!forceRefresh) {
          return _cached!;
        }
      }
    } else if (!forceRefresh) {
      return _cached!;
    }

    if (!_canCallFirebase) {
      _cached ??= PlanStatusSnapshot.fallback();
      return _cached!;
    }

    if (!forceRefresh && _lastFetch != null) {
      final minutesSinceFetch = DateTime.now().difference(_lastFetch!).inMinutes;
      if (minutesSinceFetch < 5 && _cached != null) {
        return _cached!;
      }
    }

    return await _refreshFromRemote() ?? (_cached ?? PlanStatusSnapshot.fallback());
  }

  static Future<PlanStatusSnapshot> refreshPlanStatus() async {
    return await getPlanStatus(forceRefresh: true);
  }

  static Future<void> clearCachedStatus() async {
    _cached = null;
    _lastFetch = null;
    await StorageService.clearPlanStatus();
  }

  static Future<PlanStatusSnapshot?> _refreshFromRemote() async {
    if (!_canCallFirebase) {
      return _cached;
    }

    try {
      final callable = FirebaseGuard.functions()!.httpsCallable(
        'getPlanStatus',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      final response = await callable.call();
      final data = Map<String, dynamic>.from(response.data as Map);
      final snapshot = PlanStatusSnapshot.fromJson(data);

      await StorageService.savePlanStatus(snapshot.toJson());
      await StorageService.saveSubscriptionTier(snapshot.tier);

      _cached = snapshot;
      _lastFetch = DateTime.now();
      return snapshot;
    } catch (error, stackTrace) {
      debugPrint('Plan status fetch failed: $error');
      debugPrint('$stackTrace');
      return _cached;
    }
  }
}
