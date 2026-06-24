import 'package:equatable/equatable.dart';

abstract class RatingEvent extends Equatable {
  const RatingEvent();

  @override
  List<Object?> get props => [];
}

class SubmitRating extends RatingEvent {
  final String tripId;
  final double rating;
  final String? comment;

  const SubmitRating({
    required this.tripId,
    required this.rating,
    this.comment,
  });

  @override
  List<Object?> get props => [tripId, rating, comment];
}
