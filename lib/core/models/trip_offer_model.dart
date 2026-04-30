// lib/core/models/trip_offer_model.dart
import 'package:equatable/equatable.dart';

/// Status values allowed by the `chk_trip_offers_status` constraint.
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

/// Type-safe model for the `trip_offers` table.
/// Maps exactly to the PostgreSQL schema columns.
class TripOfferModel extends Equatable {
  final String id;
  final String tripId;
  final String driverId;
  final TripOfferStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  const TripOfferModel({
    required this.id,
    required this.tripId,
    required this.driverId,
    this.status = TripOfferStatus.pending,
    this.createdAt,
    this.respondedAt,
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
    );
  }

  bool get isPending => status == TripOfferStatus.pending;
  bool get isAccepted => status == TripOfferStatus.accepted;

  @override
  List<Object?> get props => [
        id, tripId, driverId, status, createdAt, respondedAt,
      ];
}
