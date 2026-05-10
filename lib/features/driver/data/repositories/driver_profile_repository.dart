
import '../../../../../services/supabase_service.dart';



class DriverProfileRepository {
  final _client = SupabaseService.client;

  
  Future<Map<String, dynamic>?> loadDriverProfile(String driverId) async {
    final results = await Future.wait([
      _client.from('users').select('id,name,phone,avatar_url,rating,total_trips,language,is_active').eq('id', driverId).single(),
      _client.from('drivers_profile').select('*').eq('id', driverId).single(),
      _client
          .from('driver_earnings_summary')
          .select('total_earnings, available_balance, completed_trips')
          .eq('driver_id', driverId)
          .maybeSingle(),
    ]);

    final userData = results[0] as Map<String, dynamic>;
    final driverData = results[1] as Map<String, dynamic>;
    final earningsData = results[2] as Map<String, dynamic>?;

    final merged = Map<String, dynamic>.from(userData);
    driverData.forEach((key, value) {
      if (key != 'id' && key != 'updated_at' && key != 'created_at') {
        merged[key] = value;
      }
    });

    // أرباح المحفظة الفعلية
    if (earningsData != null) {
      merged['total_earnings'] = earningsData['total_earnings'];
      merged['available_balance'] = earningsData['available_balance'];
      merged['completed_trips_wallet'] = earningsData['completed_trips'];
    }

    return merged;
  }

  
  Future<Map<String, dynamic>?> updateDriverProfile(
    String driverId,
    Map<String, dynamic> data,
  ) async {
    
    final userFields = {'name', 'phone', 'avatar_url'};
    final usersUpdate = <String, dynamic>{};
    final driversUpdate = <String, dynamic>{};

    data.forEach((key, value) {
      if (userFields.contains(key)) {
        usersUpdate[key] = value;
      } else {
        driversUpdate[key] = value;
      }
    });

    
    final updateFutures = <Future>[];
    if (usersUpdate.isNotEmpty) {
      usersUpdate['updated_at'] = DateTime.now().toIso8601String();
      updateFutures.add(_client
          .from('users')
          .update(usersUpdate)
          .eq('id', driverId));
    }
    if (driversUpdate.isNotEmpty) {
      driversUpdate['updated_at'] = DateTime.now().toIso8601String();
      updateFutures.add(_client
          .from('drivers_profile')
          .update(driversUpdate)
          .eq('id', driverId));
    }

    if (updateFutures.isNotEmpty) await Future.wait(updateFutures);

    
    return await loadDriverProfile(driverId);
  }
}
