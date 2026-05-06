
import 'package:flutter/foundation.dart';
import '../core/utils/geohash_helper.dart';
import 'supabase_service.dart';



class TripBroadcastService {
  TripBroadcastService._();
  static final TripBroadcastService instance = TripBroadcastService._();

  
  static void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  
  
  Future<List<String>> findNearbyDrivers({
    required double originLat,
    required double originLng,
    required String vehicleType,
  }) async {
    _log('🔍 TripBroadcast: ========== START findNearbyDrivers ==========');
    _log('🔍 TripBroadcast: originLat=$originLat, originLng=$originLng, vehicleType=$vehicleType');
    
    
    final originCell = GeohashHelper.encode(originLat, originLng, precision: 5);
    final neighbors = GeohashHelper.getNeighborCells(originCell);
    final searchCells = [originCell, ...neighbors];

    _log(
        '🔍 TripBroadcast: Searching ${searchCells.length} cells around $originCell for vehicleType="$vehicleType"');
    _log('🔍 TripBroadcast: Search cells: $searchCells');

    try {
      _log('🔍 TripBroadcast: Querying Supabase for available drivers...');
      
      final cleanVehicleType = vehicleType.trim().toLowerCase();
      
      final results = await SupabaseService.client
          .from('drivers_profile')
          .select('id, geohash, geohash5, vehicle_type')
          .eq('is_available', true)
          .inFilter('geohash5', searchCells)
          .ilike('vehicle_type', cleanVehicleType);
      
      _log('🔍 TripBroadcast: Supabase returned ${results.length} available "$cleanVehicleType" drivers total.');

      
      
      if (results.isNotEmpty) {
        _log('🔍 TripBroadcast: All available drivers:');
        for (final row in results) {
          _log('   - Driver ${row['id']}: geohash5=${row['geohash5']}, vehicle=${row['vehicle_type']}');
        }
      }

      
      final matchingDriverIds = <String>[];
      for (final row in results) {
        
        final driverGeohash5 = row['geohash5'] as String?;
        final driverGeohash = row['geohash'] as String?;
        final driverId = row['id'] as String;

        String? driverCell;
        if (driverGeohash5 != null) {
          driverCell = driverGeohash5;
        } else if (driverGeohash != null && driverGeohash.length >= 5) {
          driverCell = driverGeohash.substring(0, 5);
        }

        if (driverCell == null) {
          _log('🔍 TripBroadcast: Driver $driverId - geohash5 too short or null: $driverGeohash5 / $driverGeohash');
          continue;
        }
        if (searchCells.contains(driverCell)) {
          matchingDriverIds.add(driverId);
          _log('🔍 TripBroadcast: ✅ Driver $driverId in cell $driverCell - MATCHED');
        } else {
          _log('🔍 TripBroadcast: ❌ Driver $driverId in cell $driverCell - not in search cells');
        }
      }

      _log(
          '🔍 TripBroadcast: Found ${matchingDriverIds.length} matching drivers after cell filter');

      return matchingDriverIds;
    } catch (e) {
      _log('❌ TripBroadcast: Error finding drivers: $e');
      return [];
    }
  }

  
  
  Future<void> broadcastTripOffers({
    required String tripId,
    required List<String> driverIds,
  }) async {
    _log('📤 TripBroadcast: Starting broadcast for trip $tripId to ${driverIds.length} drivers: $driverIds');
    
    if (driverIds.isEmpty) {
      _log('⚠️ TripBroadcast: No drivers to send offers to!');
      return;
    }

    try {
      
      _log('📤 TripBroadcast: Checking for existing offers...');
      final existing = await SupabaseService.client
          .from('trip_offers')
          .select('driver_id')
          .eq('trip_id', tripId)
          .eq('status', 'pending');
      
      final existingDriverIds = (existing as List)
          .map((row) => row['driver_id'] as String)
          .toSet();
      
      _log('📤 TripBroadcast: Found ${existingDriverIds.length} existing offers');
      
      
      final newDriverIds = driverIds
          .where((id) => !existingDriverIds.contains(id))
          .toList();
      
      _log('📤 TripBroadcast: ${newDriverIds.length} new drivers to notify: $newDriverIds');
      
      if (newDriverIds.isEmpty) {
        _log('📤 TripBroadcast: All drivers already have offers for trip $tripId');
        return;
      }

      final offers = newDriverIds.map((driverId) => {
            'trip_id': tripId,
            'driver_id': driverId,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }).toList();

      _log('📤 TripBroadcast: Inserting ${offers.length} offers...');
      await SupabaseService.client.from('trip_offers').insert(offers);

      _log(
          '📤 TripBroadcast: ✅ Successfully sent ${offers.length} offers for trip $tripId to drivers: $newDriverIds');

      // 🔥 CRITICAL FIX: Explicitly send FCM notification to wake up the driver's background isolate
      for (final driverId in newDriverIds) {
        try {
          _log('📤 TripBroadcast: Invoking send-fcm for driver $driverId');
          await SupabaseService.client.functions.invoke('send-fcm', body: {
            'user_id': driverId,
            'title': 'رحلة جديدة',
            'body': 'لديك طلب رحلة جديد بالقرب منك',
            'data': {
              'type': 'ride_offer',
              'trip_id': tripId,
            },
          });
        } catch (e) {
          _log('❌ TripBroadcast: Failed to send FCM to $driverId: $e');
        }
      }
    } catch (e) {
      _log('❌ TripBroadcast: Error broadcasting offers: $e');
      
      if (e.toString().contains('42501') || e.toString().contains('violates row-level')) {
        _log('🚨 TripBroadcast: RLS policy error! Check trip_offers table policies.');
      }
    }
  }
}
