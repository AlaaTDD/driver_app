// lib/features/user/presentation/trips/bloc/trips_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../data/trips_repository.dart';
import 'trips_event.dart';
import 'trips_state.dart';

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

      // Load trips via repository
      final trips = await _repository.loadUserTrips(userId);

      // Fetch driver details for trips that have a driver
      final driverIds = trips
          .where((t) => t['driver_id'] != null)
          .map((t) => t['driver_id'] as String)
          .toSet()
          .toList();

      if (driverIds.isNotEmpty) {
        try {
          // FIX H10: Fetch driver details via repository
          final driversMap = await _repository.fetchDriverDetails(driverIds);

          for (final trip in trips) {
            final driverId = trip['driver_id'];
            if (driverId != null && driversMap.containsKey(driverId)) {
              trip['driver'] = driversMap[driverId];
            }
          }
        } catch (e) {
          // Driver fetch failed but trips are still loaded
          debugPrint('⚠️ TripsBloc: Could not fetch driver details: $e');
        }
      }

      emit(TripsLoaded(trips));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading trips: $e');
      }
      emit(const TripsError('errorLoadTrips'));
    }
  }

  Future<void> _onLoadTripDetails(
    LoadTripDetails event,
    Emitter<TripsState> emit,
  ) async {
    emit(TripDetailsLoading());
    try {
      // Load trip details via repository
      final trip = await _repository.loadTripDetails(event.tripId);

      if (trip == null) {
        emit(const TripsError('errorLoadTripDetails'));
        return;
      }

      // Fetch driver details if available
      final driverId = trip['driver_id'];
      if (driverId != null) {
        final driverData = await _repository.fetchSingleDriverDetails(driverId);
        if (driverData != null) {
          trip['driver'] = driverData;
        }
      }

      emit(TripDetailsLoaded(trip));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading trip details: $e');
      }
      emit(const TripsError('errorLoadTripDetails'));
    }
  }

  Future<void> _onCancelUserTrip(
    CancelUserTrip event,
    Emitter<TripsState> emit,
  ) async {
    emit(TripsLoading());
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(const TripsError('errorNotLoggedIn'));
        return;
      }

      // FIX C04: Validate trip state before cancelling
      final trip = await _repository.getTripForCancellation(event.tripId);
      if (trip == null) {
        emit(const TripsError('errorCancelTrip'));
        return;
      }

      // Only the trip owner can cancel
      if (trip['user_id'] != userId) {
        emit(const TripsError('errorNotYourTrip'));
        return;
      }

      // Only cancellable states
      final status = trip['status'] as String?;
      if (status != 'searching' && status != 'accepted') {
        emit(const TripsError('errorCancelStatus'));
        return;
      }

      // Cancel trip via repository
      await _repository.cancelTrip(event.tripId, userId);

      emit(const TripActionSuccess('successTripCancelled'));
    } catch (e) {
      debugPrint('❌ TripsBloc: CancelTrip failed: $e');
      emit(const TripsError('errorCancelTrip'));
    }
  }

  Future<void> _onSubmitTripComplaint(
    SubmitTripComplaint event,
    Emitter<TripsState> emit,
  ) async {
    emit(TripsLoading());
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
        debugPrint('Error submitting complaint: $e');
      }
      emit(const TripsError('errorSendComplaint'));
    }
  }
}
