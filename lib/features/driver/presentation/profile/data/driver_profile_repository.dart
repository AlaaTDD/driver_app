// lib/features/driver/presentation/profile/data/driver_profile_repository.dart
import '../../../../../services/supabase_service.dart';

/// Repository for Driver Profile operations.
/// Encapsulates all Supabase data access for driver profile features.
class DriverProfileRepository {
  final _client = SupabaseService.client;

  /// Load driver profile data from users and drivers_profile tables
  Future<Map<String, dynamic>?> loadDriverProfile(String driverId) async {
    // FIX H08: Parallelize the two queries instead of sequential
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

    // FIX H11: Merge without overwriting user identity fields
    final merged = Map<String, dynamic>.from(userData);
    driverData.forEach((key, value) {
      // Don't overwrite user's id or updated_at with driver's values
      if (key != 'id' && key != 'updated_at' && key != 'created_at') {
        merged[key] = value;
      }
    });

    return merged;
  }

  /// Update driver profile in both users and drivers_profile tables
  Future<Map<String, dynamic>?> updateDriverProfile(
    String driverId,
    Map<String, dynamic> data,
  ) async {
    // Split update data between users and drivers_profile tables
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

    // FIX L06: Run updates in parallel instead of sequentially
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

    // Reload full merged profile
    return await loadDriverProfile(driverId);
  }
}
