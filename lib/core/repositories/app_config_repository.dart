import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/supabase_service.dart';

/// Repository for app-level configuration (feature flags, min versions, etc.)
/// Reads from the `app_config` table and supports realtime updates.
class AppConfigRepository {
  final _client = SupabaseService.client;

  /// Cache to avoid redundant queries within the same session.
  final Map<String, dynamic> _cache = {};

  /// Get a single config value by key.
  Future<dynamic> getValue(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final data = await _client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      if (data != null) {
        final value = data['value'];
        _cache[key] = value;
        return value;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ AppConfigRepository.getValue($key): $e');
      return null;
    }
  }

  /// Get all config entries, optionally filtered by category.
  Future<Map<String, dynamic>> getAll({String? category}) async {
    try {
      var query = _client.from('app_config').select('key, value, label, category');
      if (category != null) {
        query = query.eq('category', category);
      }
      final data = await query;
      final result = <String, dynamic>{};
      for (final row in (data as List)) {
        result[row['key'] as String] = row['value'];
      }
      _cache.addAll(result);
      return result;
    } catch (e) {
      debugPrint('⚠️ AppConfigRepository.getAll: $e');
      return {};
    }
  }

  /// Check if a feature flag is enabled.
  Future<bool> isFeatureEnabled(String featureKey) async {
    try {
      final value = await getValue(featureKey);
      if (value is Map && value.containsKey('value')) {
        return value['value'] == true;
      }
      if (value is Map && value.containsKey('enabled')) {
        return value['enabled'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ AppConfigRepository.isFeatureEnabled($featureKey): $e');
      return false;
    }
  }

  /// Get minimum app version for the current platform.
  Future<String?> getMinAppVersion(String platform) async {
    try {
      final value = await getValue('min_app_version');
      if (value is Map && value.containsKey(platform)) {
        return value[platform] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ AppConfigRepository.getMinAppVersion: $e');
      return null;
    }
  }

  /// Check if maintenance mode is active.
  Future<bool> isMaintenanceMode() async {
    try {
      final value = await getValue('maintenance_mode');
      if (value is Map) {
        return value['enabled'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ AppConfigRepository.isMaintenanceMode: $e');
      return false;
    }
  }

  /// Stream config changes in realtime.
  Stream<Map<String, dynamic>> watchConfig() {
    return _client
        .from('app_config')
        .stream(primaryKey: ['key'])
        .map((rows) {
      final result = <String, dynamic>{};
      for (final row in rows) {
        result[row['key'] as String] = row['value'];
      }
      _cache.addAll(result);
      return result;
    });
  }

  /// Clear cached values (e.g. on user logout).
  void clearCache() => _cache.clear();

  /// Get default map center from config or fallback to constants
  Future<LatLng?> getDefaultMapCenter() async {
    final config = await getAll();
    final lat = double.tryParse(config['default_lat']?.toString() ?? '');
    final lng = double.tryParse(config['default_lng']?.toString() ?? '');
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null; // fallback
  }
}
