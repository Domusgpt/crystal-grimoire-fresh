import 'package:http/http.dart' as http;
import '../services/environment_config.dart';

/// Backend API Configuration for CrystalGrimoire
class BackendConfig {
  static final EnvironmentConfig _config = EnvironmentConfig.instance;
  // Environment-based backend URL configuration
  static const bool _isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const String _customBackendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');

  // Backend API URL - Environment based
  static String get baseUrl {
    final url = _configuredBaseUrl;
    if (url == null) {
      throw StateError('Backend URL is not configured for this build.');
    }
    return url;
  }

  static String? get _configuredBaseUrl {
    final override = _config.backendUrl.trim().isNotEmpty
        ? _config.backendUrl.trim()
        : _customBackendUrl.trim();

    if (override.isNotEmpty) {
      final sanitized = override.endsWith('/') ? override.substring(0, override.length - 1) : override;
      return sanitized.endsWith('/api') ? sanitized : '$sanitized/api';
    }

    if (_config.useLocalBackend && !_isProduction) {
      return 'http://localhost:8081/api';
    }

    return null;
  }

  // Use backend API if available, otherwise use direct AI
  static bool get useBackend => forceBackendIntegration || _configuredBaseUrl != null;

  // Environment-based backend forcing
  static bool get forceBackendIntegration {
    const forced = bool.fromEnvironment('FORCE_BACKEND', defaultValue: false);
    return forced && _configuredBaseUrl != null;
  }
  
  // API Endpoints
  static const String identifyEndpoint = '/crystal/identify';
  static const String collectionEndpoint = '/crystal/collection';
  static const String saveEndpoint = '/crystal/save';
  static const String usageEndpoint = '/usage';
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);
  
  // Headers
  static Map<String, String> get headers => {
    'Accept': 'application/json',
    // Add auth headers when implemented
  };
  
  // Check if backend is available
  static Future<bool> isBackendAvailable() async {
    if (!useBackend) return false;

    final url = _configuredBaseUrl;
    if (url == null) {
      return false;
    }

    try {
      final healthUrl = url.replaceAll('/api', '/health');
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: headers,
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Backend not available at $baseUrl: $e');
      return false;
    }
  }
  
  // Get configuration summary
  static Map<String, dynamic> getConfigSummary() {
    return {
      'base_url': _configuredBaseUrl ?? 'disabled',
      'is_production': _isProduction,
      'custom_backend_url': (_config.backendUrl.isNotEmpty || _customBackendUrl.isNotEmpty)
          ? 'configured'
          : 'not_set',
      'use_backend': useBackend,
      'force_backend': forceBackendIntegration,
      'endpoints': {
        'identify': _configuredBaseUrl != null ? '${_configuredBaseUrl!}$identifyEndpoint' : 'disabled',
        'collection': _configuredBaseUrl != null ? '${_configuredBaseUrl!}$collectionEndpoint' : 'disabled',
        'save': _configuredBaseUrl != null ? '${_configuredBaseUrl!}$saveEndpoint' : 'disabled',
        'usage': _configuredBaseUrl != null ? '${_configuredBaseUrl!}$usageEndpoint' : 'disabled',
      }
    };
  }
}