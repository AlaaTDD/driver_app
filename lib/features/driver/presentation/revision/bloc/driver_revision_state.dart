import 'package:equatable/equatable.dart';
import 'package:snapix/core/models/revision_request_model.dart';

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
  final List<RevisionRequestModel> requests;

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
