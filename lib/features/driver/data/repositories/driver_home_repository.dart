// /host/Volumes/alaaMac/driverr/taxi/taxi_app/lib/features/driver/data/repositories/driver_home_repository.dart
//
// ✅ FIX (Map Module):
//   1. setDriverOnline: الـ RPC يأخذ (p_geohash, p_geohash5) — نمرّرهم صح
//   2. pushLocation: يستخدم النسخة الموحدة من upsert_driver_location
//   3. getNearbyDriversSecure: استخدام get_nearby_drivers_secure(p_geohash5 text[])
//      بدلاً من get_nearby_drivers القديمة التي تبحث في driver_locations

import 'package:snapix/core/models/driver_earnings_model.dart';
import 'package:snapix/core/repositories/driver_earnings_helper.dart';
import 'package:snapix/core/utils/geohash_helper.dart';
import 'package:snapix/features/trips/data/models/trip_model.dart';
import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverHomeRepository {
  final _client = SupabaseService.client;

  /// فحص دفاعي في العمق: يتحقق أن `account_status == 'approved'` مباشرة من
  /// الداتابيز قبل تفعيل أي إجراء حساس (تفعيل التوفر، قبول رحلة). لا يعتمد
  /// حصرياً على أن AppRouter منع السائق من الوصول لهذه الشاشة أصلاً — لأن
  /// RLS على `trips`/`driver_locations` (المرحلة ب، البند 6) لم تُكتب بعد
  /// حتى وقت كتابة هذه الدالة، فهذا الفحص هو خط الدفاع الفعلي الوحيد حالياً
  /// ضد استدعاء الإجراءات الحساسة مباشرة عبر .rpc() متجاوزاً الواجهة.
  /// انظر MASTER_PLAN.md القسم 4، المرحلة ج، البند 14.
  Future<bool> isDriverApproved(String userId) async {
    try {
      final data = await _client
          .from('drivers_profile')
          .select('account_status')
          .eq('id', userId)
          .single();
      return data['account_status'] == 'approved';
    } catch (e) {
      AppLogger.error('DriverHomeRepository: isDriverApproved check failed: $e');
      // فشل الفحص نفسه (مشكلة شبكة مثلاً) → نرفض بحذر بدلاً من افتراض الاعتماد.
      return false;
    }
  }

  Future<Map<String, dynamic>> loadDriverStatus(String userId) async {
    final results = await Future.wait([
      _client
          .from('drivers_profile')
          .select('is_available')
          .eq('id', userId)
          .single(),
      _client
          .from('users')
          .select('rating, total_trips')
          .eq('id', userId)
          .single(),
    ]);

    return {
      'driverData': results[0],
      'userData': results[1],
    };
  }

  Future<DriverEarningsModel> getEarningsSummary(String userId) async {
    return DriverEarningsHelper.fetch(userId);
  }

  /// يُغير السائق لـ online مع حساب الـ geohash وإرساله للـ RPC
  /// RPC Signature: set_driver_online(p_driver_id, p_lat, p_lng, p_geohash, p_geohash5)
  Future<void> setDriverOnline(
    String userId,
    double lat,
    double lng,
  ) async {
    final geohash = GeohashHelper.encode(lat, lng); // precision=6
    final geohash5 = GeohashHelper.encode(lat, lng, precision: 5);

    await _client.rpc('set_driver_online', params: {
      'p_driver_id': userId,
      'p_lat': lat,
      'p_lng': lng,
      'p_geohash': geohash,
      'p_geohash5': geohash5,
    });

    // بعد set_driver_online نبعت كمان upsert_driver_location عشان:
    // 1. updated_at يتجدد للحظة → get_nearby_drivers_secure يلاقيه
    // 2. driver_locations تتحدث للـ analytics
    // 3. السائق الواقف (ما بيتحركش) يظهر دايماً للمستخدم
    try {
      await _client.rpc('upsert_driver_location', params: {
        'p_driver_id': userId,
        'p_lat': lat,
        'p_lng': lng,
        'p_heading': 0.0,
        'p_geohash': geohash,
        'p_geohash5': geohash5,
      });
    } catch (e) {
      // set_driver_online نجح — فشل upsert مش حرج
      AppLogger.warning('DriverHomeRepository: upsert after online failed: $e');
    }

    AppLogger.debug(
        'DriverHomeRepository: setDriverOnline [$lat,$lng] gh=$geohash gh5=$geohash5');
  }

  Future<void> setDriverOffline(String userId) async {
    await _client.rpc('set_driver_offline', params: {
      'p_driver_id': userId,
    });
  }

  /// يبث تغييرات `is_available` من صفّ السواق في `drivers_profile` عبر realtime.
  ///
  /// الهدف: الزر "متاح/غير متاح" في الواجهة يفضل مرآة لمصدر الحقيقة في
  /// الداتابيز. لمّا الـ DB (cron الـ 15 دقيقة، الـ admin، أو أي تغيير) يقلّب
  /// `is_available`، الـ stream ده يلتقط التغيير فورًا → الواجهة تتحدث لوحدها.
  ///
  /// القيم: `true` / `false`، أو `null` لو الصف اختفى (نُعامله كـ غير متاح).
  ///
  /// نفس النمط المتبع في `wallet_repository.watchDriverWallet`.
  Stream<bool?> watchDriverAvailability(String userId) {
    return _client
        .from('drivers_profile')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) =>
            rows.isEmpty ? null : rows.first['is_available'] as bool? ?? false);
  }

  /// يُحدّث موقع السائق في DB
  /// يستخدم النسخة الموحدة من upsert_driver_location
  Future<void> pushLocation(
    String userId,
    double lat,
    double lng, {
    double? heading,
  }) async {
    final geohash = GeohashHelper.encode(lat, lng); // precision=6
    final geohash5 = geohash.length > 5 ? geohash.substring(0, 5) : geohash;

    await _client.rpc('upsert_driver_location', params: {
      'p_driver_id': userId,
      'p_lat': lat,
      'p_lng': lng,
      'p_heading': heading ?? 0.0,
      'p_geohash': geohash,
      'p_geohash5': geohash5,
    });
  }

  /// استخدام get_nearby_drivers_secure(p_geohash5 text[])
  ///  - تبحث في drivers_profile مباشرة (أكثر دقة من driver_locations)
  ///  - تتحقق من is_verified و current_lat IS NOT NULL
  ///  - تقبل 9 خلايا (خلية مركزية + 8 مجاورين)
  Future<List<Map<String, dynamic>>> getNearbyDriversSecure(
    double lat,
    double lng, {
    int precision = 5,
  }) async {
    final cells =
        GeohashHelper.getCellAndNeighbors(lat, lng, precision: precision);

    final result = await _client.rpc(
      'get_nearby_drivers_secure',
      params: {'p_geohash5': cells},
    );

    return List<Map<String, dynamic>>.from(result as List);
  }

  // NOTE: acceptTrip() and rejectTrip() are in TripDetailsRepository.
  // Use TripDetailsRepository for trip lifecycle actions to avoid duplication.

  Future<bool> hasActiveTrip(String userId) async {
    final activeTrips = await _client
        .from('trips')
        .select('id')
        .eq('driver_id', userId)
        .inFilter('status',
            ['accepted', 'driver_arriving', 'in_progress']).maybeSingle();
    return activeTrips != null;
  }

  Future<List<TripModel>> fetchTripsByIds(List<String> tripIds) async {
    if (tripIds.isEmpty) return [];
    final tripList = await _client
        .from('trips')
        .select('*, user:user_id(name, avatar_url, phone)')
        .inFilter('id', tripIds)
        .eq('status', 'searching');
    return (tripList as List)
        .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> getTripOffersStream(String userId) {
    return _client
        .from('trip_offers')
        .stream(primaryKey: ['id']).eq('driver_id', userId);
  }
}
