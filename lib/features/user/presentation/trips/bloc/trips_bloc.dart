import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/supabase_service.dart';
import 'package:snapix/features/user/data/repositories/trips_repository.dart';
import 'trips_event.dart';
import 'trips_state.dart';
import 'package:snapix/core/utils/trip_status.dart';
import 'package:snapix/core/utils/app_logger.dart';

class TripsBloc extends Bloc<TripsEvent, TripsState> {
  final TripsRepository _repository = TripsRepository();

  TripsBloc() : super(TripsInitial()) {
    on<LoadUserTrips>(_onLoadUserTrips);
    on<LoadTripDetails>(_onLoadTripDetails);
    on<CancelUserTrip>(_onCancelUserTrip);
    on<SubmitTripComplaint>(_onSubmitTripComplaint);
  }

  Future<void> _onLoadUserTrips(
    LoadUserTrips event,
    Emitter<TripsState> emit,
  ) async {
    emit(TripsLoading());
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(const TripsLoaded([]));
        return;
      }

      final trips = await _repository.loadUserTrips(userId);

      final driverIds = trips
          .where((t) => t.driverId != null)
          .map((t) => t.driverId!)
          .toSet()
          .toList();

      if (driverIds.isNotEmpty) {
        try {
          final driversMap = await _repository.fetchDriverDetails(driverIds);

          for (int i = 0; i < trips.length; i++) {
            final driverId = trips[i].driverId;
            if (driverId != null && driversMap.containsKey(driverId)) {
              trips[i] = trips[i].copyWith(userData: driversMap[driverId]!.toJson());
            }
          }
        } catch (e) {
          AppLogger.warning('TripsBloc: Could not fetch driver details: $e');
        }
      }

      emit(TripsLoaded(trips));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug('Error loading trips: $e');
      }
      emit(const TripsError('errorLoadTrips'));
    }
  }

  Future<void> _onLoadTripDetails(
    LoadTripDetails event,
    Emitter<TripsState> emit,
  ) async {
    if (!event.silent) emit(TripDetailsLoading());
    try {
      var trip = await _repository.loadTripDetails(event.tripId);

      if (trip == null) {
        emit(const TripsError('errorLoadTripDetails'));
        return;
      }

      final driverId = trip.driverId;
      if (driverId != null) {
        final driverInfo = await _repository.fetchSingleDriverDetails(driverId);
        if (driverInfo != null) {
          trip = trip.copyWith(driverData: driverInfo);
        }
      }

      emit(TripDetailsLoaded(trip));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug('Error loading trip details: $e');
      }
      emit(const TripsError('errorLoadTripDetails'));
    }
  }

  Future<void> _onCancelUserTrip(
    CancelUserTrip event,
    Emitter<TripsState> emit,
  ) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(const TripsError('errorNotLoggedIn'));
        return;
      }

      final trip = await _repository.getTripForCancellation(event.tripId);
      if (trip == null) {
        emit(const TripsError('errorCancelTrip'));
        return;
      }

      if (trip['user_id'] != userId) {
        emit(const TripsError('errorNotYourTrip'));
        return;
      }

      final status = trip['status'] as String?;
      final tripStatus = TripStatus.fromString(status);
      if (tripStatus == null || !tripStatus.isCancellable) {
        emit(const TripsError('errorCancelStatus'));
        return;
      }

      await _repository.cancelTrip(event.tripId, userId);

      emit(const TripActionSuccess('successTripCancelled'));
    } catch (e) {
      AppLogger.error('TripsBloc: CancelTrip failed: $e');
      emit(const TripsError('errorCancelTrip'));
    }
  }

  Future<void> _onSubmitTripComplaint(
    SubmitTripComplaint event,
    Emitter<TripsState> emit,
  ) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      await _repository.submitComplaint(
        userId: userId,
        tripId: event.tripId,
        title: event.title,
        description: event.description,
      );
      emit(const TripActionSuccess('successComplaintSent'));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug('Error submitting complaint: $e');
      }
      emit(const TripsError('errorSendComplaint'));
    }
  }
}
