
import 'package:dartz/dartz.dart';
import '../../../../core/utils/trip_status.dart';
import '../entities/trip_entity.dart';

abstract class TripRepository {
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
  });

  Future<Either<String, List<TripEntity>>> getUserTrips(String userId);

  Future<Either<String, TripEntity?>> getActiveTrip(String userId);

  Future<Either<String, void>> cancelTrip({
    required String tripId,
    required String cancelledBy,
    String? cancelReason,
  });

  Future<Either<String, void>> updateTripStatus({
    required String tripId,
    required TripStatus newStatus,
  });

  Future<Either<String, List<TripEntity>>> getAvailableTrips({
    required double lat,
    required double lng,
    required String vehicleType,
  });
}
