import 'package:equatable/equatable.dart';
import '../data/models/ride_offer_model.dart';

abstract class RideOfferEvent extends Equatable {
  const RideOfferEvent();

  @override
  List<Object?> get props => [];
}

class RideOfferReceived extends RideOfferEvent {
  final RideOfferModel offer;
  const RideOfferReceived(this.offer);

  @override
  List<Object?> get props => [offer];
}

class RideOfferAccepted extends RideOfferEvent {
  final String offerId;
  const RideOfferAccepted(this.offerId);

  @override
  List<Object?> get props => [offerId];
}

class RideOfferDeclined extends RideOfferEvent {
  final String offerId;
  const RideOfferDeclined(this.offerId);

  @override
  List<Object?> get props => [offerId];
}

class RideOfferTimerTick extends RideOfferEvent {
  final int remainingSeconds;
  const RideOfferTimerTick(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

class RideOfferDismissed extends RideOfferEvent {
  const RideOfferDismissed();
}
