import 'package:equatable/equatable.dart';

abstract class SearchingEvent extends Equatable {
  const SearchingEvent();

  @override
  List<Object?> get props => [];
}

class StartSearching extends SearchingEvent {
  final String tripId;
  final String title;
  final String body;

  const StartSearching(this.tripId, {required this.title, required this.body});

  @override
  List<Object?> get props => [tripId, title, body];
}

class TimerTick extends SearchingEvent {
  final int remainingSeconds;

  const TimerTick(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

class TripStatusChanged extends SearchingEvent {
  final Map<String, dynamic> trip;

  const TripStatusChanged(this.trip);

  @override
  List<Object?> get props => [trip];
}

class CancelSearch extends SearchingEvent {
  final String tripId;
  final String? cancelReason;

  const CancelSearch(this.tripId, {this.cancelReason});

  @override
  List<Object?> get props => [tripId, cancelReason];
}

class RebroadcastTripOffers extends SearchingEvent {
  final String tripId;
  final String title;
  final String body;

  const RebroadcastTripOffers(this.tripId, {required this.title, required this.body});

  @override
  List<Object?> get props => [tripId, title, body];
}

class OffersUpdated extends SearchingEvent {
  final List<Map<String, dynamic>> offers;
  const OffersUpdated(this.offers);

  @override
  List<Object?> get props => [offers];
}

class AcceptDriverOffer extends SearchingEvent {
  final String offerId;
  const AcceptDriverOffer(this.offerId);

  @override
  List<Object?> get props => [offerId];
}
