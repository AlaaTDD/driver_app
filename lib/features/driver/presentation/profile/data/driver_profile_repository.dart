
import '../../../../../services/supabase_service.dart';



class DriverProfileRepository {
  final _client = SupabaseService.client;

  
  Future<Map<String, dynamic>?> loadDriverProfile(String driverId) async {
    
    final results = await Future.wait([
      _client
          .from('users')
          .select('*')
          .eq('id', driverId)
          .single(),
      _client
          .from('drivers_profile')
          .select('*')
          .eq('id', driverId)
          .single(),
    ]);

    final userData = results[0];
    final driverData = results[1];

    
    final merged = Map<String, dynamic>.from(userData);
    driverData.forEach((key, value) {
      
      if (key != 'id' && key != 'updated_at' && key != 'created_at') {
        merged[key] = value;
      }
    });

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
