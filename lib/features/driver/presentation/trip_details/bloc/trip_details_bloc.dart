
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../services/location_service.dart';
import '../../../../../core/utils/geohash_helper.dart';
import 'package:snapix/features/driver/data/repositories/trip_details_repository.dart';
import 'trip_details_event.dart';
import 'trip_details_state.dart';

class TripDetailsBloc extends Bloc<TripDetailsEvent, TripDetailsState> {
  final TripDetailsRepository _repository;

  TripDetailsBloc({TripDetailsRepository? repository})
      : _repository = repository ?? TripDetailsRepository(),
        super(TripDetailsInitial()) {
    on<LoadTripDetails>(_onLoadTripDetails);
    on<AcceptTrip>(_onAcceptTrip);
    on<RejectTrip>(_onRejectTrip);
    on<StartTrip>(_onStartTrip);
    on<CompleteTrip>(_onCompleteTrip);
  }

  void _manageLocationTracking(String? status) {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    
    if (status == 'accepted' || status == 'in_progress') {
      LocationService.instance.startTripTracking(userId);
    } else if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
      LocationService.instance.stopTripTracking();
    }
  }

  // We no longer need _onUpdateDriverLocation since it's handled globally by LocationService

  Future<void> _onLoadTripDetails(
    LoadTripDetails event,
    Emitter<TripDetailsState> emit,
  ) async {
    emit(TripDetailsLoading());
    try {
      final data = await _repository.loadTripDetails(event.tripId);
      _manageLocationTracking(data['status'] as String?);
      emit(TripDetailsLoaded(data));
    } catch (e, stackTrace) {
      debugPrint('❌ TripDetailsBloc: Load failed: $e');
      debugPrint(stackTrace.toString());
      emit(TripDetailsError('errorLoadTripDetails'));
    }
  }

  Future<void> _onAcceptTrip(
    AcceptTrip event,
    Emitter<TripDetailsState> emit,
  ) async {
    try {
      final result = await _repository.acceptTrip(event.tripId);

      if (result != null && result['success'] == true) {
        final updated = await _repository.loadTripDetails(event.tripId);
        _manageLocationTracking(updated['status'] as String?);
        emit(TripDetailsLoaded(updated));
      } else {
        emit(TripDetailsError(result?['error']?.toString() ?? 'errorAcceptTrip'));
      }
    } catch (e) {
      emit(TripDetailsError('errorAcceptTrip'));
    }
  }

  Future<void> _onRejectTrip(
    RejectTrip event,
    Emitter<TripDetailsState> emit,
  ) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(TripDetailsError('errorNotLoggedIn'));
        return;
      }

      await _repository.rejectTripOffer(
        tripId: event.tripId,
        driverId: userId,
      );

      
      final updated = await _repository.loadTripDetails(event.tripId);
      _manageLocationTracking(updated['status'] as String?);
      emit(TripDetailsLoaded(updated));
    } catch (e) {
      emit(TripDetailsError('errorRejectTrip'));
    }
  }

  Future<void> _onStartTrip(
    StartTrip event,
    Emitter<TripDetailsState> emit,
  ) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(TripDetailsError('errorNotLoggedIn'));
        return;
      }

      final result = await _repository.startTrip(
        tripId: event.tripId,
        driverId: userId,
      );

      if (result != null && result['success'] == true) {
        final updated = await _repository.loadTripDetails(event.tripId);
        _manageLocationTracking(updated['status'] as String?);
        emit(TripDetailsLoaded(updated));
      } else {
        emit(TripDetailsError(result?['error']?.toString() ?? 'errorStartTrip'));
      }
    } catch (e) {
      emit(TripDetailsError('errorStartTrip'));
    }
  }

  Future<void> _onCompleteTrip(
    CompleteTrip event,
    Emitter<TripDetailsState> emit,
  ) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(TripDetailsError('errorNotLoggedIn'));
        return;
      }

      final result = await _repository.completeTrip(
        tripId: event.tripId,
        driverId: userId,
      );

      if (result != null && result['success'] == true) {
        final updated = await _repository.loadTripDetails(event.tripId);
        _manageLocationTracking(updated['status'] as String?);
        emit(TripDetailsLoaded(updated));
      } else {
        emit(TripDetailsError(result?['error']?.toString() ?? 'errorCompleteTrip'));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ CompleteTrip failed: $e');
      debugPrint(stackTrace.toString());
      emit(TripDetailsError('errorCompleteTrip'));
    }
  }

  @override
  Future<void> close() {
    // We do NOT stop global tracking here, as it should continue even if user navigates away from the screen
    return super.close();
  }
}
