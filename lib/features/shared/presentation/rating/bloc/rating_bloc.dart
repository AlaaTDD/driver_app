import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/supabase_service.dart';
import 'package:snapix/features/shared/data/repositories/rating_repository.dart';
import 'rating_event.dart';
import 'rating_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

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

      final tripUserId = tripData['user_id'] as String?;
      final tripDriverId = tripData['driver_id'] as String?;

      if (tripUserId == null || tripDriverId == null) {
        emit(const RatingError('errorNoDriverForTrip'));
        return;
      }

      final isDriverRating = userId == tripDriverId;

      if (isDriverRating) {
        if (tripData['driver_rating_to_user'] != null) {
          emit(const RatingError('errorAlreadyRated'));
          return;
        }
      } else {
        if (tripData['user_rating_to_driver'] != null) {
          emit(const RatingError('errorTripAlreadyRated'));
          return;
        }
      }

      final hasExisting = await _repository.hasExistingRating(
          event.tripId, userId, tripUserId, tripDriverId);
      if (hasExisting) {
        emit(const RatingError('errorAlreadyRated'));
        return;
      }

      await _repository.submitRating(
        tripId: event.tripId,
        currentUserId: userId,
        tripUserId: tripUserId,
        tripDriverId: tripDriverId,
        rating: event.rating.toInt(),
        comment: event.comment,
      );

      emit(RatingSuccess());
    } catch (e, stackTrace) {
      AppLogger.error('RatingBloc: Failed to submit rating: $e');
      AppLogger.debug(stackTrace.toString());
      emit(const RatingError('errorSubmitRating'));
    }
  }
}
