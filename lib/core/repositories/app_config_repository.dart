import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/core/models/app_config_model.dart';
import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Repository for app-level configuration (feature flags, min versions, etc.)
/// Reads from the `app_config` table and supports realtime updates.
class AppConfigRepository {
  final _client = SupabaseService.client;

  /// Cache to avoid redundant queries within the same session.
  final Map<String, Object?> _cache = {};

  /// Get a single config value by key.
  Future<T> getValue<T>(String key, T defaultValue) async {
    if (_cache.containsKey(key)) {
      final cached = _cache[key];
      return cached is T ? cached : defaultValue;
    }
    try {
      final data = await _client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      if (data != null) {
        final value = data['value'];
        _cache[key] = value;
        return value is T ? value : defaultValue;
      }
      return defaultValue;
    } catch (e) {
      AppLogger.warning('AppConfigRepository.getValue($key): $e');
      return defaultValue;
    }
  }

  /// Get all config entries, optionally filtered by category.
  Future<AppConfigModel> getAll({String? category}) async {
    try {
      var query =
          _client.from('app_config').select('key, value, label, category');
      if (category != null) {
        query = query.eq('category', category);
      }
      final data = await query;
      final result = <String, Object?>{};
      for (final row in (data as List)) {
        result[row['key'] as String] = row['value'];
      }
      _cache.addAll(result);
      return AppConfigModel(result);
    } catch (e) {
      AppLogger.warning('AppConfigRepository.getAll: $e');
      return const AppConfigModel.empty();
    }
  }

  /// Check if a feature flag is enabled.
  Future<bool> isFeatureEnabled(String featureKey) async {
    try {
      final value = await getValue<Object?>(featureKey, null);
      if (value is Map && value.containsKey('value')) {
        return value['value'] == true;
      }
      if (value is Map && value.containsKey('enabled')) {
        return value['enabled'] == true;
      }
      return false;
    } catch (e) {
      AppLogger.warning(
          'AppConfigRepository.isFeatureEnabled($featureKey): $e');
      return false;
    }
  }

  /// Get minimum app version for the current platform.
  Future<String?> getMinAppVersion(String platform) async {
    try {
      final value = await getValue<Object?>('min_app_version', null);
      if (value is Map && value.containsKey(platform)) {
        return value[platform] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.warning('AppConfigRepository.getMinAppVersion: $e');
      return null;
    }
  }

  /// Check if maintenance mode is active.
  Future<bool> isMaintenanceMode() async {
    try {
      final value = await getValue<Object?>('maintenance_mode', null);
      if (value is Map) {
        return value['enabled'] == true;
      }
      return false;
    } catch (e) {
      AppLogger.warning('AppConfigRepository.isMaintenanceMode: $e');
      return false;
    }
  }

  /// Stream config changes in realtime.
  Stream<AppConfigModel> watchConfig() {
    return _client.from('app_config').stream(primaryKey: ['key']).map((rows) {
      final result = <String, Object?>{};
      for (final row in rows) {
        result[row['key'] as String] = row['value'];
      }
      _cache.addAll(result);
      return AppConfigModel(result);
    });
  }

  /// Clear cached values (e.g. on user logout).
  void clearCache() => _cache.clear();

  /// Get default map center from config or fallback to constants
  Future<LatLng?> getDefaultMapCenter() async {
    final config = await getAll();
    final center = config.getRaw('default_map_center');
    if (center is Map) {
      final lat = double.tryParse(center['lat']?.toString() ?? '');
      final lng = double.tryParse(center['lng']?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    final lat = double.tryParse(
      (config.getRaw('default_lat') ?? config.getRaw('default_map_lat'))
              ?.toString() ??
          '',
    );
    final lng = double.tryParse(
      (config.getRaw('default_lng') ?? config.getRaw('default_map_lng'))
              ?.toString() ??
          '',
    );
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null; // fallback
  }
}
