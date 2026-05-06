
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/trip_status.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../../../core/utils/geohash_helper.dart';
import '../../../../services/supabase_service.dart';
import '../models/trip_model.dart';

class TripRepositoryImpl implements TripRepository {
  @override
  Future<Either<String, TripEntity>> createTrip({
    required String userId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    required String vehicleType,
    required double distanceKm,
    required double price,
  }) async {
    try {
      
      final existingTrip = await SupabaseService.client
          .from('trips')
          .select('id')
          .eq('user_id', userId)
          .inFilter('status', [
            TripStatus.searching.toDbString(),
            TripStatus.accepted.toDbString(),
            TripStatus.inProgress.toDbString(),
          ])
          .maybeSingle();
      
      if (existingTrip != null) {
        return const Left('errorActiveTripExists');
      }

      final geohash = GeohashHelper.encode(pickupLat, pickupLng);

      final tripData = await SupabaseService.client.from('trips').insert({
        'user_id': userId,
        'pickup_address': pickupAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'destination_address': destinationAddress,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'vehicle_type': vehicleType,
        'distance_km': distanceKm,
        'price': price,
        'status': TripStatus.searching.toDbString(),
        'is_paid': false,
        'geohash': geohash,
      }).select().single();

      final tripModel = TripModel.fromJson(tripData);
      return Right(tripModel.toEntity());
    } catch (e, stackTrace) {
      debugPrint('TripRepositoryImpl.createTrip error: $e\n$stackTrace');
      return Left('failedCreateTrip');
    }
  }

  @override
  Future<Either<String, List<TripEntity>>> getUserTrips(String userId) async {
    try {
      final tripsData = await SupabaseService.client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final trips = tripsData
          .map((data) => TripModel.fromJson(data).toEntity())
          .toList();
      return Right(trips);
    } catch (e, stackTrace) {
      debugPrint('TripRepositoryImpl.getUserTrips error: $e\n$stackTrace');
      return Left('failedFetchTrips');
    }
  }

  @override
  Future<Either<String, TripEntity?>> getActiveTrip(String userId) async {
    try {
      final tripData = await SupabaseService.client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .inFilter('status', [
            TripStatus.searching.toDbString(),
            TripStatus.accepted.toDbString(),
            TripStatus.inProgress.toDbString(),
          ])
          .maybeSingle();

      if (tripData == null) {
        return const Right(null);
      }

      final tripModel = TripModel.fromJson(tripData);
      return Right(tripModel.toEntity());
    } catch (e, stackTrace) {
      debugPrint('TripRepositoryImpl.getActiveTrip error: $e\n$stackTrace');
      return const Right(null);
    }
  }

  @override
  Future<Either<String, void>> cancelTrip({
    required String tripId,
    required String cancelledBy,
    String? cancelReason,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'cancel_trip',
        params: {
          'p_trip_id': tripId,
          'p_user_id': SupabaseService.currentUser!.id,
          'p_cancelled_by': cancelledBy,
          if (cancelReason != null) 'p_cancel_reason': cancelReason,
        },
      );
      if (response != true) {
        return const Left('failedCancelTrip');
      }
      return const Right(null);
    } catch (e, stackTrace) {
      debugPrint('TripRepositoryImpl.cancelTrip error: $e\n$stackTrace');
      return Left('failedCancelTrip');
    }
  }

  @override
  Future<Either<String, void>> updateTripStatus({
    required String tripId,
    required TripStatus newStatus,
  }) async {
    try {
      
      final tripData = await SupabaseService.client
          .from('trips')
          .select('status')
          .eq('id', tripId)
          .single();

      final currentStatus = TripStatus.fromString(tripData['status'] as String?);
      if (currentStatus == null) {
        return const Left('errorInvalidCurrentStatus');
      }

      
      if (!currentStatus.canTransitionTo(newStatus)) {
        return const Left('errorInvalidStatusTransition');
      }

      final updateData = <String, dynamic>{
        'status': newStatus.toDbString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (newStatus == TripStatus.inProgress) {
        updateData['started_at'] = DateTime.now().toUtc().toIso8601String();
      } else if (newStatus == TripStatus.accepted) {
        updateData['accepted_at'] = DateTime.now().toUtc().toIso8601String();
      } else if (newStatus == TripStatus.completed) {
        updateData['completed_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await SupabaseService.client
          .from('trips')
          .update(updateData)
          .eq('id', tripId);
      return const Right(null);
    } catch (e, stackTrace) {
      debugPrint('TripRepositoryImpl.updateTripStatus error: $e\n$stackTrace');
      return const Left('failedUpdateTrip');
    }
  }

  @override
  Future<Either<String, List<TripEntity>>> getAvailableTrips({
    required double lat,
    required double lng,
    required String vehicleType,
  }) async {
    try {
      final geohash = GeohashHelper.encode(lat, lng);
      final neighborCells = GeohashHelper.getNeighborCells(geohash);
      neighborCells.add(geohash);

      final tripsData = await SupabaseService.client
          .from('trips')
          .select()
          .inFilter('geohash', neighborCells)
          .eq('status', TripStatus.searching.toDbString())
          .eq('vehicle_type', vehicleType)
          .order('created_at', ascending: true);

      final trips = tripsData
          .map((data) => TripModel.fromJson(data).toEntity())
          .toList();
      return Right(trips);
    } catch (e, stackTrace) {
      debugPrint('TripRepositoryImpl.getAvailableTrips error: $e\n$stackTrace');
      return Left('failedFetchAvailableTrips');
    }
  }
}
