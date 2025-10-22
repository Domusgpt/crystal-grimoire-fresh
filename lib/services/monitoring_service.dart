import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_guard.dart';

/// Centralised telemetry hooks for analytics, error tracking, and lightweight
/// performance timings. Designed to operate safely when Firebase is not
/// configured (Flutter web preview mode).
class MonitoringService {
  MonitoringService._();

  static final MonitoringService instance = MonitoringService._();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  /// Initialises analytics and hooks global error handlers when Firebase is
  /// available. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!FirebaseGuard.isConfigured) {
      debugPrint('MonitoringService: Firebase not configured, running in noop mode.');
      _initialized = true;
      return;
    }

    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      FlutterError.onError = (FlutterErrorDetails details) {
        recordError(details.exception, details.stack,
            context: const {'source': 'flutter_error'});
        FlutterError.presentError(details);
      };
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('MonitoringService initialisation failed: $error');
      _initialized = true;
      recordError(error, stackTrace, context: const {
        'phase': 'initialization',
      });
    }
  }

  /// Records an analytics event when analytics is available.
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters.map(
          (key, value) => MapEntry(key, _serialiseValue(value)),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to log event "$name": $error');
      recordError(error, stackTrace, context: {
        'event': name,
        ...parameters,
      });
    }
  }

  /// Associates analytics with a given user identifier.
  Future<void> setUserId(String? uid) async {
    if (uid == null || uid.isEmpty) {
      return;
    }
    try {
      await _analytics?.setUserId(id: uid);
    } catch (error, stackTrace) {
      recordError(error, stackTrace, context: {
        'operation': 'setUserId',
      });
    }
  }

  /// Clears the analytics user identifier.
  Future<void> clearUserId() async {
    try {
      await _analytics?.setUserId(id: null);
    } catch (error, stackTrace) {
      recordError(error, stackTrace, context: {
        'operation': 'clearUserId',
      });
    }
  }

  /// Records errors so they can be surfaced in analytics dashboards.
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object?>{
      'message': error.toString(),
      if (context.isNotEmpty) 'context': context,
    };
    debugPrint('Telemetry error captured: ${payload['message']}');
    // Log a structured analytics event when available.
    unawaited(logEvent('client_exception', parameters: payload));
    // Always fall back to console output for environments without analytics.
  }

  /// Records a callable invocation result. Duration is reported in
  /// milliseconds for quick dashboard aggregation.
  Future<void> logFunctionInvocation(
    String functionName, {
    required bool success,
    Duration? duration,
    Map<String, Object?> metadata = const {},
  }) async {
    await logEvent('callable_invocation', parameters: {
      'function': functionName,
      'success': success,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
      ...metadata,
    });
  }

  Object? _serialiseValue(Object? value) {
    if (value == null) return null;
    if (value is num || value is String || value is bool) {
      return value;
    }
    if (value is Duration) {
      return value.inMilliseconds;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }
}
