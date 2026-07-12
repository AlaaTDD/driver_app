import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snapix/core/models/driver_profile_model.dart';
import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverProfileRepository {
  final _client = SupabaseService.client;

  Future<DriverProfileModel?> loadDriverProfile(String driverId) async {
    final results = await Future.wait([
      _client
          .from('users')
          .select(
              'id,name,phone,avatar_url,rating,total_trips,language,is_active')
          .eq('id', driverId)
          .single(),
      // [البند 17 — المراجعة النهائية] أُضيف account_status و revision_reason
      // هنا بعد اكتشاف أن استعلام شاشة البروفايل لم يكن يجلبهما إطلاقاً —
      // ما كان يعني أن DriverProfileModel.fromJson كانت تُسقِط دائماً على
      // pendingReview الافتراضية (orElse في DriverAccountStatus.fromValue)
      // بصرف النظر عن الحالة الحقيقية للسائق. انظر MASTER_PLAN.md القسم 4،
      // المرحلة د، البند 17.
      _client.from('drivers_profile').select('id, vehicle_category, vehicle_brand, vehicle_model, vehicle_plate, vehicle_color, is_verified, is_available, account_status, revision_reason, target_origin_lat, target_origin_lng, target_dest_lat, target_dest_lng, target_route_lat, target_route_lng, target_route_address, updated_at').eq('id', driverId).single(),
      _client
          .from('driver_earnings_summary')
          .select('total_earnings, available_balance, completed_trips')
          .eq('driver_id', driverId)
          .maybeSingle(),
    ]);

    final userData = results[0] as Map<String, dynamic>;
    final driverData = results[1] as Map<String, dynamic>;
    final earningsData = results[2];

    final merged = Map<String, dynamic>.from(userData);
    driverData.forEach((key, value) {
      if (key != 'id' && key != 'updated_at') {
        merged[key] = value;
      }
    });

    // أرباح المحفظة الفعلية
    if (earningsData != null) {
      merged['total_earnings'] = earningsData['total_earnings'];
      merged['available_balance'] = earningsData['available_balance'];
      merged['completed_trips_wallet'] = earningsData['completed_trips'];
    }

    return DriverProfileModel.fromJson(merged);
  }

  /// Realtime stream for driver profile changes (e.g. admin verification).
  Stream<DriverProfileModel?> watchDriverProfile(String driverId) {
    final controller = StreamController<DriverProfileModel?>.broadcast();

    Future<void> reload() async {
      try {
        final data = await loadDriverProfile(driverId);
        if (!controller.isClosed) controller.add(data);
      } catch (e, st) {
        AppLogger.warning('DriverProfileRepository: reload failed: $e\n$st');
      }
    }

    reload();

    final channel = SupabaseService.client
        .channel('driver-profile-$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers_profile',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: driverId,
          ),
          callback: (_) => reload(),
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<DriverProfileModel?> updateDriverProfile(
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
      updateFutures
          .add(_client.from('users').update(usersUpdate).eq('id', driverId));
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
