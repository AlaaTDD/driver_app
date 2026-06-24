import 'package:equatable/equatable.dart';

abstract class DriverProfileEvent extends Equatable {
  const DriverProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadDriverProfile extends DriverProfileEvent {
  const LoadDriverProfile();
}

class UpdateDriverProfile extends DriverProfileEvent {
  final Map<String, dynamic> data;

  const UpdateDriverProfile(this.data);

  @override
  List<Object?> get props => [data];
}
