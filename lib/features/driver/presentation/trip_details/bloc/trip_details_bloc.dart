// lib/features/driver/presentation/trip_details/bloc/trip_details_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../data/trip_details_repository.dart';
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

  Future<void> _onLoadTripDetails(
    LoadTripDetails event,
    Emitter<TripDetailsState> emit,
  ) async {
    emit(TripDetailsLoading());
    try {
      final data = await _repository.loadTripDetails(event.tripId);
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

      // Reload trip details to reflect any other changes
      final updated = await _repository.loadTripDetails(event.tripId);
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
        emit(TripDetailsLoaded(updated));
      } else {
        emit(TripDetailsError(result?['error']?.toString() ?? 'errorCompleteTrip'));
      }
    } catch (e) {
      emit(TripDetailsError('errorCompleteTrip'));
    }
  }
}
