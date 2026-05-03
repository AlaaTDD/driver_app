
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../data/rating_repository.dart';
import 'rating_event.dart';
import 'rating_state.dart';

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  final RatingRepository _repository = RatingRepository();

  RatingBloc() : super(RatingInitial()) {
    on<SubmitRating>(_onSubmitRating);
  }

  Future<void> _onSubmitRating(
    SubmitRating event,
    Emitter<RatingState> emit,
  ) async {
    emit(RatingLoading());
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(const RatingError('errorNotLoggedIn'));
        return;
      }

      
      final tripData = await _repository.getTripData(event.tripId);
      if (tripData == null) {
        emit(const RatingError('errorNoDriverForTrip'));
        return;
      }

      final driverId = tripData['driver_id'] as String?;
      if (driverId == null) {
        emit(const RatingError('errorNoDriverForTrip'));
        return;
      }

      
      
      if (tripData['user_rating_to_driver'] != null) {
        emit(const RatingError('errorTripAlreadyRated'));
        return;
      }

      
      final hasExisting = await _repository.hasExistingRating(event.tripId, userId);
      if (hasExisting) {
        emit(const RatingError('errorAlreadyRated'));
        return;
      }

      
      await _repository.submitRating(
        tripId: event.tripId,
        userId: userId,
        driverId: driverId,
        rating: event.rating.toInt(),
        comment: event.comment,
      );

      emit(RatingSuccess());
    } catch (e, stackTrace) {
      debugPrint('❌ RatingBloc: Failed to submit rating: $e');
      debugPrint(stackTrace.toString());
      emit(const RatingError('errorSubmitRating'));
    }
  }
}
