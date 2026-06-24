import 'package:equatable/equatable.dart';
import 'package:snapix/core/models/driver_profile_model.dart';

abstract class DriverProfileState extends Equatable {
  const DriverProfileState();

  @override
  List<Object?> get props => [];
}

class DriverProfileInitial extends DriverProfileState {}

class DriverProfileLoading extends DriverProfileState {}

class DriverProfileLoaded extends DriverProfileState {
  final DriverProfileModel driver;

  const DriverProfileLoaded(this.driver);

  @override
  List<Object?> get props => [driver];
}

class DriverProfileError extends DriverProfileState {
  final String message;

  const DriverProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
