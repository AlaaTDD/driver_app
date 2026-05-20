import 'package:flutter/foundation.dart';
import '../../../../services/supabase_service.dart';

/// Repository for driver bonus/incentive system.
/// Wraps the `bonus_rules`, `driver_bonus_ledger` tables and related RPCs.
class BonusRepository {
  final _client = SupabaseService.client;

  /// Get the current driver's bonus progress for today.
  /// Uses the `get_my_bonus_progress` RPC.
  Future<Map<String, dynamic>> getMyBonusProgress([String? driverId]) async {
    try {
      final result = await _client.rpc('get_my_bonus_progress');
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result.first);
      }
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      if (driverId != null) {
        try {
          final result = await _client.rpc(
            'get_my_bonus_progress',
            params: {'p_driver_id': driverId},
          );
          if (result is List && result.isNotEmpty) {
            return Map<String, dynamic>.from(result.first);
          }
          if (result is Map) {
            return Map<String, dynamic>.from(result);
          }
        } catch (fallbackError) {
          debugPrint(
              '❌ BonusRepository.getMyBonusProgress fallback: $fallbackError');
        }
      }
      debugPrint('❌ BonusRepository.getMyBonusProgress: $e');
      return {};
    }
  }

  /// Get active bonus rules applicable to the driver.
  Future<List<Map<String, dynamic>>> getActiveBonusRules({
    String? vehicleType,
    String? serviceAreaId,
  }) async {
    try {
      var query = _client.from('bonus_rules').select('*').eq('is_active', true);

      final data = await query.order('threshold', ascending: true);

      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ BonusRepository.getActiveBonusRules: $e');
      return [];
    }
  }

  /// Get driver's bonus ledger history.
  Future<List<Map<String, dynamic>>> getBonusHistory(
    String driverId, {
    int limit = 20,
  }) async {
    try {
      final data = await _client
          .from('driver_bonus_ledger')
          .select('*, bonus_rules(name, name_ar, trigger_type, bonus_amount)')
          .eq('driver_id', driverId)
          .order('awarded_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ BonusRepository.getBonusHistory: $e');
      return [];
    }
  }
}
