
import 'package:equatable/equatable.dart';

abstract class SearchingState extends Equatable {
  const SearchingState();

  @override
  List<Object?> get props => [];
}

class SearchingInitial extends SearchingState {}

class SearchingInProgress extends SearchingState {
  final int remainingSeconds;
  final String tripId;

  const SearchingInProgress({
    required this.remainingSeconds,
    required this.tripId,
  });

  @override
  List<Object?> get props => [remainingSeconds, tripId];
}

class SearchingSuccess extends SearchingState {
  final Map<String, dynamic> trip;
  final Map<String, dynamic>? driver;

  const SearchingSuccess({
    required this.trip,
    this.driver,
  });

  @override
  List<Object?> get props => [trip, driver];
}

class SearchingNoDrivers extends SearchingState {
  final String message;

  const SearchingNoDrivers({this.message = 'noDriversAvailable'});

  @override
  List<Object?> get props => [message];
}

class SearchingCancelled extends SearchingState {
  const SearchingCancelled();
}

class SearchingError extends SearchingState {
  final String message;

  const SearchingError(this.message);

  @override
  List<Object?> get props => [message];
}
