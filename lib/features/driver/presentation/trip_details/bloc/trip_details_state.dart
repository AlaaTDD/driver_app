
import 'package:equatable/equatable.dart';

abstract class TripDetailsState extends Equatable {
  const TripDetailsState();

  @override
  List<Object?> get props => [];
}

class TripDetailsInitial extends TripDetailsState {}

class TripDetailsLoading extends TripDetailsState {}

class TripDetailsLoaded extends TripDetailsState {
  final Map<String, dynamic> trip;

  const TripDetailsLoaded(this.trip);

  @override
  List<Object?> get props => [trip];
}

class TripDetailsError extends TripDetailsState {
  final String message;

  const TripDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}
