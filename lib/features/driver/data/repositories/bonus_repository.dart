import 'package:snapix/core/models/bonus_progress_model.dart';
import 'package:snapix/core/models/bonus_rule_model.dart';
import '../../../../core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Repository for driver bonus/incentive system.
/// Wraps the `bonus_rules`, `driver_bonus_ledger` tables and related RPCs.
class BonusRepository {
  final _client = SupabaseService.client;

  /// Get the current driver's bonus progress for today.
  /// Uses the `get_my_bonus_progress` RPC.
  Future<BonusProgressModel> getMyBonusProgress([String? driverId]) async {
    try {
      final result = await _client.rpc('get_my_bonus_progress');
      if (result is List && result.isNotEmpty) {
        return BonusProgressModel.fromJson(
          Map<String, dynamic>.from(result.first as Map),
        );
      }
      if (result is Map) {
        return BonusProgressModel.fromJson(Map<String, dynamic>.from(result));
      }
      return const BonusProgressModel();
    } catch (e) {
      if (driverId != null) {
        try {
          final result = await _client.rpc(
            'get_my_bonus_progress',
            params: {'p_driver_id': driverId},
          );
          if (result is List && result.isNotEmpty) {
            return BonusProgressModel.fromJson(
              Map<String, dynamic>.from(result.first as Map),
            );
          }
          if (result is Map) {
            return BonusProgressModel.fromJson(
              Map<String, dynamic>.from(result),
            );
          }
        } catch (fallbackError) {
          AppLogger.debug(
              '❌ BonusRepository.getMyBonusProgress fallback: $fallbackError');
        }
      }
      AppLogger.error('BonusRepository.getMyBonusProgress: $e');
      return const BonusProgressModel();
    }
  }

  /// Get active bonus rules applicable to the driver.
  Future<List<BonusRuleModel>> getActiveBonusRules({
    String? vehicleType,
    String? serviceAreaId,
  }) async {
    try {
      var query = _client
          .from('bonus_rules')
          .select(
              'id, name, name_ar, trigger_type, threshold, bonus_amount, is_active, vehicle_types, service_area_id, starts_at, expires_at, created_at')
          .eq('is_active', true);

      final data = await query.order('threshold', ascending: true);

      return (data as List)
          .whereType<Map>()
          .map((e) => BonusRuleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('BonusRepository.getActiveBonusRules: $e');
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
      AppLogger.error('BonusRepository.getBonusHistory: $e');
      return [];
    }
  }
}
