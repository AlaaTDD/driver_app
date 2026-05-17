import 'package:equatable/equatable.dart';

abstract class DriverProfileState extends Equatable {
  const DriverProfileState();

  @override
  List<Object?> get props => [];
}

class DriverProfileInitial extends DriverProfileState {}

class DriverProfileLoading extends DriverProfileState {}

class DriverProfileLoaded extends DriverProfileState {
  final Map<String, dynamic> driver;

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
