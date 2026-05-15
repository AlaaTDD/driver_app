import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';

/// Shared helper to fetch driver earnings data from both the
/// summary view and the detailed RPC. Used by DriverHomeRepository
/// and WalletRepository to avoid logic duplication (BL-04).
class DriverEarningsHelper {
  static final _client = SupabaseService.client;

  /// Fetches merged earnings data from `driver_earnings_summary` view
  /// and `get_driver_earnings_detailed` RPC.
  static Future<Map<String, dynamic>> fetch(String driverId) async {
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

      return {
        'totalEarnings': (summary['total_earnings'] as num?)?.toDouble() ?? 0,
        'availableBalance': (summary['available_balance'] as num?)?.toDouble() ?? 0,
        'earningsThisWeek': (detailed['earnings_7d'] as num?)?.toDouble() ?? 0,
        'earningsLast30Days': (summary['earnings_30d'] as num?)?.toDouble()
            ?? (detailed['earnings_30d'] as num?)?.toDouble()
            ?? 0,
        'completedTrips': (summary['completed_trips'] as int?) ?? 0,
        // pass through raw data for consumers that need it
        '_raw_summary': summary,
        '_raw_detailed': detailed,
      };
    } catch (e) {
      debugPrint('⚠️ DriverEarningsHelper.fetch failed: $e');
      return {
        'totalEarnings': 0.0,
        'availableBalance': 0.0,
        'earningsThisWeek': 0.0,
        'earningsLast30Days': 0.0,
        'completedTrips': 0,
      };
    }
  }
}
