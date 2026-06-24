import 'package:snapix/core/models/driver_earnings_model.dart';
import '../../core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Shared helper to fetch driver earnings data from both the
/// summary view and the detailed RPC. Used by DriverHomeRepository
/// and WalletRepository to avoid logic duplication (BL-04).
class DriverEarningsHelper {
  static final _client = SupabaseService.client;

  /// Fetches merged earnings data from `driver_earnings_summary` view
  /// and `get_driver_earnings_detailed` RPC.
  static Future<DriverEarningsModel> fetch(String driverId) async {
    try {
      final results = await Future.wait([
        _client
            .from('driver_earnings_summary')
            .select()
            .eq('driver_id', driverId)
            .single(),
        _client.rpc('get_driver_earnings_detailed', params: {
          'p_driver_id': driverId,
        }).then((res) {
          if (res is List && res.isNotEmpty) return res.first;
          if (res is Map) return res;
          return <String, dynamic>{};
        }).catchError((_) => <String, dynamic>{}),
      ]);

      final summary = results[0] as Map<String, dynamic>;
      final detailed = results[1] as Map<String, dynamic>? ?? {};

      return DriverEarningsModel.fromJson({
        'total_earnings': summary['total_earnings'],
        'available_balance': summary['available_balance'],
        'earnings_7d': summary['earnings_7d'] ?? detailed['earnings_7d'],
        'earnings_30d': summary['earnings_30d'] ?? detailed['earnings_30d'],
        'completed_trips': summary['completed_trips'],
        'pending_withdrawal': summary['pending_withdrawal'],
      });
    } catch (e) {
      AppLogger.warning('DriverEarningsHelper.fetch failed: $e');
      return const DriverEarningsModel();
    }
  }
}
