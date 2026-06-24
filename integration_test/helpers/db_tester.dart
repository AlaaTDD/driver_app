import 'package:supabase_flutter/supabase_flutter.dart';

class DbTester {
  final SupabaseClient client = Supabase.instance.client;

  /// Retrieves a specific trip by its ID
  Future<Map<String, dynamic>?> getTrip(String tripId) async {
    final response = await client.from('trips').select().eq('id', tripId).maybeSingle();
    return response;
  }

  /// Injects a new trip request as if a user requested it
  Future<String> injectTripRequest({
    required String userId,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String originAddress,
    required String destAddress,
    required double expectedPrice,
    required double distance,
  }) async {
    final response = await client.from('trips').insert({
      'user_id': userId,
      'status': 'searching',
      'pickup_lat': originLat,
      'pickup_lng': originLng,
      'destination_lat': destLat,
      'destination_lng': destLng,
      'pickup_address': originAddress,
      'destination_address': destAddress,
      'price': expectedPrice,
      'distance': distance,
      'vehicle_type': 'car',
    }).select('id').single();

    return response['id'] as String;
  }

  /// Simulates a driver offering a price for a trip
  Future<String> injectDriverOffer({
    required String tripId,
    required String driverId,
    required double offerPrice,
    required double driverLat,
    required double driverLng,
  }) async {
    final response = await client.from('trip_offers').insert({
      'trip_id': tripId,
      'driver_id': driverId,
      'offer_price': offerPrice,
      'status': 'pending',
      'driver_lat': driverLat,
      'driver_lng': driverLng,
    }).select('id').single();

    return response['id'] as String;
  }

  /// Accepts a trip offer and updates the trip status
  Future<void> acceptOffer(String tripId, String offerId, String driverId) async {
    await client.rpc('accept_trip_offer', params: {
      'p_trip_id': tripId,
      'p_offer_id': offerId,
      'p_driver_id': driverId,
    });
  }

  /// Sets a driver's availability status
  Future<void> setDriverStatus(String driverId, bool isAvailable) async {
    await client.from('drivers_profile').update({
      'is_available': isAvailable,
    }).eq('id', driverId);
  }

  /// Completes a trip
  Future<void> completeTrip(String tripId) async {
    await client.from('trips').update({
      'status': 'completed',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }
}
