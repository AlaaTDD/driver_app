import 'package:flutter/foundation.dart';
import '../core/utils/geohash_helper.dart';
import 'supabase_service.dart';

class TripBroadcastService {
  TripBroadcastService._();
  static final TripBroadcastService instance = TripBroadcastService._();

  static void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<List<String>> findAndBroadcast({
    required String tripId,
    required double originLat,
    required double originLng,
    required String vehicleType,
    required String title,
    required String body,
    Set<String> excludedDriverIds = const {},
  }) async {
    _log(
        '🔍 TripBroadcast: ========== START secure_broadcast_trip_offers ==========');

    final originCell = GeohashHelper.encode(originLat, originLng, precision: 5);
    final searchCells = [
      originCell,
      ...GeohashHelper.getNeighborCells(originCell)
    ];

    try {
      final response = await SupabaseService.client.rpc(
        'secure_broadcast_trip_offers',
        params: {
          'p_trip_id': tripId,
          'p_search_cells': searchCells,
          'p_vehicle_type': vehicleType.trim().toLowerCase(),
        },
      );

      _log('🔍 TripBroadcast: RPC Response: $response');

      if (response != null && response['success'] == true) {
        final driverIdsRaw = response['driver_ids'] as List?;
        if (driverIdsRaw == null || driverIdsRaw.isEmpty) return const [];

        final driverIds = driverIdsRaw
            .map((e) => e.toString())
            .where((id) => !excludedDriverIds.contains(id))
            .toList();
        if (driverIds.isEmpty) {
          _log('📤 TripBroadcast: No new drivers to notify');
          return const [];
        }
        _log('📤 TripBroadcast: Sending FCM to ${driverIds.length} drivers');

        // Send FCM notifications to wake up the drivers
        for (final driverId in driverIds) {
          try {
            await SupabaseService.client.functions.invoke('send-fcm', body: {
              'user_id': driverId,
              'title': title,
              'body': body,
              'data': {
                'type': 'ride_offer',
                'trip_id': tripId,
              },
            });
          } catch (e) {
            _log('❌ TripBroadcast: Failed to send FCM to $driverId: $e');
          }
        }
        return driverIds;
      } else {
        _log('⚠️ TripBroadcast: RPC returned false or no drivers found');
      }
    } catch (e) {
      _log('❌ TripBroadcast: Error invoking secure_broadcast_trip_offers: $e');
    }
    return const [];
  }
}
