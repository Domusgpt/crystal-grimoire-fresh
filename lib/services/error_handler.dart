import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

enum ErrorSeverity { low, medium, high, critical }

enum ErrorCategory {
  network,
  ai,
  authentication,
  firestore,
  cache,
  ui,
  payment,
  unknown
}

class CrystalError {
  final String message;
  final String? details;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final DateTime timestamp;
  final String? userId;
  final Map<String, dynamic>? context;
  final dynamic originalException;
  final StackTrace? stackTrace;

  CrystalError({
    required this.message,
    this.details,
    required this.severity,
    required this.category,
    DateTime? timestamp,
    this.userId,
    this.context,
    this.originalException,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'details': details,
      'severity': severity.name,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'context': context,
      'hasStackTrace': stackTrace != null,
    };
  }
}

class ErrorHandler {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const int _maxErrorsPerSession = 50;
  static const int _maxErrorLogSize = 1000;
  static int _errorCount = 0;
  static final List<CrystalError> _sessionErrors = [];

  /// Initialize error handling system
  static Future<void> initialize() async {
    try {
      // Enable Crashlytics collection
      await _crashlytics.setCrashlyticsCollectionEnabled(true);
      
      // Set up custom keys for better debugging
      await _crashlytics.setCustomKey('app_name', 'Crystal Grimoire');
      await _crashlytics.setCustomKey('session_start', DateTime.now().toIso8601String());
      
      // Override Flutter error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        handleFlutterError(details);
      };
      
      developer.log('Error Handler initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize error handler: $e');
    }
  }

  /// Handle Flutter framework errors
  static void handleFlutterError(FlutterErrorDetails details) {
    final error = CrystalError(
      message: 'Flutter Error: ${details.exception.toString()}',
      details: details.toString(),
      severity: _categorizeFlutterError(details),
      category: ErrorCategory.ui,
      originalException: details.exception,
      stackTrace: details.stack,
    );
    
    _logError(error);
    
    // Still report to Crashlytics
    _crashlytics.recordFlutterFatalError(details);
  }

  /// Main error handling entry point
  static Future<void> handleError(
    dynamic exception, {
    StackTrace? stackTrace,
    String? message,
    ErrorSeverity? severity,
    ErrorCategory? category,
    String? userId,
    Map<String, dynamic>? context,
  }) async {
    try {
      final error = CrystalError(
        message: message ?? _extractMessage(exception),
        details: exception.toString(),
        severity: severity ?? _categorizeSeverity(exception),
        category: category ?? _categorizeError(exception),
        userId: userId,
        context: context,
        originalException: exception,
        stackTrace: stackTrace,
      );

      await _logError(error);
    } catch (e) {
      // Fallback logging if error handling fails
      developer.log('Error handler failed: $e', error: exception);
    }
  }

  /// Handle network-related errors
  static Future<void> handleNetworkError(
    dynamic exception, {
    String? endpoint,
    int? statusCode,
    String? userId,
  }) async {
    final context = <String, dynamic>{
      'endpoint': endpoint,
      'statusCode': statusCode,
      'error_type': 'network',
    };

    await handleError(
      exception,
      message: 'Network Error: ${_extractMessage(exception)}',
      severity: _getNetworkErrorSeverity(statusCode),
      category: ErrorCategory.network,
      userId: userId,
      context: context,
    );
  }

  /// Handle AI service errors with specific context
  static Future<void> handleAIError(
    dynamic exception, {
    String? operation,
    String? model,
    int? tokenCount,
    String? userId,
  }) async {
    final context = <String, dynamic>{
      'ai_operation': operation,
      'model_used': model,
      'token_count': tokenCount,
      'error_type': 'ai_service',
    };

    await handleError(
      exception,
      message: 'AI Service Error: ${_extractMessage(exception)}',
      severity: ErrorSeverity.high,
      category: ErrorCategory.ai,
      userId: userId,
      context: context,
    );
  }

  /// Handle authentication errors
  static Future<void> handleAuthError(
    dynamic exception, {
    String? authMethod,
    String? userEmail,
  }) async {
    final context = <String, dynamic>{
      'auth_method': authMethod,
      'user_email': userEmail?.substring(0, 3) + '***', // Privacy protection
      'error_type': 'authentication',
    };

    await handleError(
      exception,
      message: 'Authentication Error: ${_extractMessage(exception)}',
      severity: ErrorSeverity.medium,
      category: ErrorCategory.authentication,
      context: context,
    );
  }

  /// Handle payment/billing errors
  static Future<void> handlePaymentError(
    dynamic exception, {
    String? operation,
    String? userId,
    double? amount,
  }) async {
    final context = <String, dynamic>{
      'payment_operation': operation,
      'amount': amount,
      'error_type': 'payment',
    };

    await handleError(
      exception,
      message: 'Payment Error: ${_extractMessage(exception)}',
      severity: ErrorSeverity.critical,
      category: ErrorCategory.payment,
      userId: userId,
      context: context,
    );
  }

  /// Log error with multiple channels
  static Future<void> _logError(CrystalError error) async {
    _errorCount++;
    
    // Prevent memory leaks from excessive error logging
    if (_sessionErrors.length >= _maxErrorLogSize) {
      _sessionErrors.removeRange(0, _maxErrorLogSize ~/ 2);
    }
    
    _sessionErrors.add(error);

    // Console logging for development
    developer.log(
      error.message,
      name: 'CrystalGrimoire',
      error: error.originalException,
      stackTrace: error.stackTrace,
    );

    // Analytics event for error tracking
    await _analytics.logEvent(
      name: 'error_occurred',
      parameters: {
        'error_category': error.category.name,
        'error_severity': error.severity.name,
        'error_message': error.message.length > 100 
            ? error.message.substring(0, 100) 
            : error.message,
        'user_id': error.userId,
      },
    );

    // Crashlytics for critical errors
    if (error.severity == ErrorSeverity.critical || error.severity == ErrorSeverity.high) {
      await _crashlytics.setCustomKey('error_category', error.category.name);
      await _crashlytics.setCustomKey('error_severity', error.severity.name);
      
      if (error.userId != null) {
        await _crashlytics.setUserIdentifier(error.userId!);
      }

      if (error.context != null) {
        for (final entry in error.context!.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value.toString());
        }
      }

      await _crashlytics.recordError(
        error.originalException ?? error.message,
        error.stackTrace,
        fatal: error.severity == ErrorSeverity.critical,
      );
    }

    // Firestore logging for production monitoring
    if (error.severity == ErrorSeverity.critical) {
      try {
        await _firestore.collection('error_logs').add({
          ...error.toJson(),
          'app_version': '1.0.0', // Should be dynamic
          'platform': 'web',
          'session_id': _getSessionId(),
        });
      } catch (e) {
        developer.log('Failed to log error to Firestore: $e');
      }
    }
  }

  /// Get current session errors for debugging
  static List<CrystalError> getSessionErrors() {
    return List.unmodifiable(_sessionErrors);
  }

  /// Get error statistics for monitoring
  static Map<String, dynamic> getErrorStats() {
    final categoryCount = <String, int>{};
    final severityCount = <String, int>{};
    
    for (final error in _sessionErrors) {
      categoryCount[error.category.name] = (categoryCount[error.category.name] ?? 0) + 1;
      severityCount[error.severity.name] = (severityCount[error.severity.name] ?? 0) + 1;
    }

    return {
      'total_errors': _errorCount,
      'session_errors': _sessionErrors.length,
      'by_category': categoryCount,
      'by_severity': severityCount,
      'error_rate': _sessionErrors.isEmpty ? 0.0 : _errorCount / _sessionErrors.length,
    };
  }

  /// Create user-friendly error message
  static String getUserFriendlyMessage(CrystalError error) {
    switch (error.category) {
      case ErrorCategory.network:
        return 'Having trouble connecting. Please check your internet and try again.';
      case ErrorCategory.ai:
        return 'Our crystal identification service is temporarily busy. Please try again in a moment.';
      case ErrorCategory.authentication:
        return 'Sign-in issue detected. Please try logging in again.';
      case ErrorCategory.firestore:
        return 'Database connection issue. Your data is safe, please try again.';
      case ErrorCategory.cache:
        return 'Storage issue detected. The app may run slower temporarily.';
      case ErrorCategory.payment:
        return 'Payment processing issue. Please check your payment method and try again.';
      case ErrorCategory.ui:
        return 'Display issue detected. Please restart the app if problems persist.';
      default:
        return 'Something unexpected happened. Please try again.';
    }
  }

  /// Clear session errors (for memory management)
  static void clearSessionErrors() {
    _sessionErrors.clear();
  }

  // PRIVATE HELPER METHODS

  static String _extractMessage(dynamic exception) {
    if (exception == null) return 'Unknown error occurred';
    if (exception is String) return exception;
    return exception.toString();
  }

  static ErrorSeverity _categorizeSeverity(dynamic exception) {
    final message = exception.toString().toLowerCase();
    
    if (message.contains('fatal') || 
        message.contains('critical') ||
        message.contains('payment') ||
        message.contains('crash')) {
      return ErrorSeverity.critical;
    }
    
    if (message.contains('network') || 
        message.contains('timeout') ||
        message.contains('ai') ||
        message.contains('api')) {
      return ErrorSeverity.high;
    }
    
    if (message.contains('cache') || 
        message.contains('storage') ||
        message.contains('auth')) {
      return ErrorSeverity.medium;
    }
    
    return ErrorSeverity.low;
  }

  static ErrorCategory _categorizeError(dynamic exception) {
    final message = exception.toString().toLowerCase();
    
    if (message.contains('network') || 
        message.contains('http') ||
        message.contains('connection') ||
        message.contains('timeout')) {
      return ErrorCategory.network;
    }
    
    if (message.contains('ai') || 
        message.contains('gemini') ||
        message.contains('vision') ||
        message.contains('model')) {
      return ErrorCategory.ai;
    }
    
    if (message.contains('auth') || 
        message.contains('sign') ||
        message.contains('login') ||
        message.contains('token')) {
      return ErrorCategory.authentication;
    }
    
    if (message.contains('firestore') || 
        message.contains('database') ||
        message.contains('collection')) {
      return ErrorCategory.firestore;
    }
    
    if (message.contains('cache') || 
        message.contains('storage') ||
        message.contains('preferences')) {
      return ErrorCategory.cache;
    }
    
    if (message.contains('payment') || 
        message.contains('stripe') ||
        message.contains('billing')) {
      return ErrorCategory.payment;
    }
    
    if (message.contains('widget') || 
        message.contains('render') ||
        message.contains('flutter')) {
      return ErrorCategory.ui;
    }
    
    return ErrorCategory.unknown;
  }

  static ErrorSeverity _categorizeFlutterError(FlutterErrorDetails details) {
    if (details.exception.toString().contains('RenderFlex overflowed')) {
      return ErrorSeverity.low;
    }
    
    if (details.exception.toString().contains('setState')) {
      return ErrorSeverity.medium;
    }
    
    return ErrorSeverity.high;
  }

  static ErrorSeverity _getNetworkErrorSeverity(int? statusCode) {
    if (statusCode == null) return ErrorSeverity.high;
    
    if (statusCode >= 500) return ErrorSeverity.critical;
    if (statusCode >= 400) return ErrorSeverity.high;
    if (statusCode >= 300) return ErrorSeverity.medium;
    
    return ErrorSeverity.low;
  }

  static String _getSessionId() {
    // Simple session ID based on app start time
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}