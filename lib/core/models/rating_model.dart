import 'package:equatable/equatable.dart';

class RatingModel extends Equatable {
  final String id;
  final String tripId;
  final String userId;
  final String driverId;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.driverId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      userId: json['user_id'] as String,
      driverId: json['driver_id'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'user_id': userId,
      'driver_id': driverId,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
    };
  }

  @override
  List<Object?> get props => [
        id,
        tripId,
        userId,
        driverId,
        rating,
        comment,
        createdAt,
      ];
}
