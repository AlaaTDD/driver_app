import 'package:equatable/equatable.dart';

enum TripOfferStatus {
  pending,
  accepted,
  rejected,
  expired;

  static TripOfferStatus? fromString(String? status) {
    switch (status) {
      case 'pending':
        return TripOfferStatus.pending;
      case 'accepted':
        return TripOfferStatus.accepted;
      case 'rejected':
        return TripOfferStatus.rejected;
      case 'expired':
        return TripOfferStatus.expired;
      default:
        return null;
    }
  }

  String toDbString() {
    switch (this) {
      case TripOfferStatus.pending:
        return 'pending';
      case TripOfferStatus.accepted:
        return 'accepted';
      case TripOfferStatus.rejected:
        return 'rejected';
      case TripOfferStatus.expired:
        return 'expired';
    }
  }
}

class TripOfferModel extends Equatable {
  final String id;
  final String tripId;
  final String driverId;
  final TripOfferStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? updatedAt;

  const TripOfferModel({
    required this.id,
    required this.tripId,
    required this.driverId,
    this.status = TripOfferStatus.pending,
    this.createdAt,
    this.respondedAt,
    this.updatedAt,
  });

  factory TripOfferModel.fromJson(Map<String, dynamic> json) {
    return TripOfferModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      driverId: json['driver_id'] as String,
      status: TripOfferStatus.fromString(json['status'] as String?) ??
          TripOfferStatus.pending,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isPending => status == TripOfferStatus.pending;
  bool get isAccepted => status == TripOfferStatus.accepted;

  @override
  List<Object?> get props => [
        id,
        tripId,
        driverId,
        status,
        createdAt,
        respondedAt,
        updatedAt,
      ];
}
