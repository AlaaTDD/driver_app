import 'package:equatable/equatable.dart';

sealed class DriverRevisionState extends Equatable {
  const DriverRevisionState();

  @override
  List<Object?> get props => [];
}

class DriverRevisionInitial extends DriverRevisionState {
  const DriverRevisionInitial();
}

class DriverRevisionLoading extends DriverRevisionState {
  const DriverRevisionLoading();
}

class DriverRevisionLoaded extends DriverRevisionState {
  final List<Map<String, dynamic>> requests;

  const DriverRevisionLoaded({required this.requests});

  @override
  List<Object?> get props => [requests];
}

class DriverRevisionError extends DriverRevisionState {
  final String errorKey;

  const DriverRevisionError(this.errorKey);

  @override
  List<Object?> get props => [errorKey];
}
