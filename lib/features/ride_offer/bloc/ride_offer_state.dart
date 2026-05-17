import 'package:equatable/equatable.dart';
import '../data/models/ride_offer_model.dart';

enum RideOfferStatus { idle, incoming, accepted, declined, expired, error }

class RideOfferState extends Equatable {
  final RideOfferStatus status;
  final RideOfferModel? currentOffer;
  final int remainingSeconds;
  final String? errorMessage;

  const RideOfferState({
    this.status = RideOfferStatus.idle,
    this.currentOffer,
    this.remainingSeconds = 30,
    this.errorMessage,
  });

  bool get hasOffer => currentOffer != null;
  bool get isActive =>
      status == RideOfferStatus.incoming || status == RideOfferStatus.accepted;

  RideOfferState copyWith({
    RideOfferStatus? status,
    RideOfferModel? currentOffer,
    int? remainingSeconds,
    String? errorMessage,
    bool clearOffer = false,
    bool clearError = false,
  }) {
    return RideOfferState(
      status: status ?? this.status,
      currentOffer: clearOffer ? null : (currentOffer ?? this.currentOffer),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      errorMessage: clearError ? null : errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, currentOffer, remainingSeconds, errorMessage];
}
