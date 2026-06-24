import 'package:equatable/equatable.dart';
import '../../../../../core/models/trip_details_model.dart';

abstract class TripDetailsState extends Equatable {
  const TripDetailsState();

  @override
  List<Object?> get props => [];
}

class TripDetailsInitial extends TripDetailsState {}

class TripDetailsLoading extends TripDetailsState {}

class TripDetailsLoaded extends TripDetailsState {
  final TripDetailsModel trip;

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

class TripCancelled extends TripDetailsState {
  const TripCancelled();
}
