part of 'corridor_cubit.dart';

enum CorridorStatus { initial, loading, loaded, saving, saved, error }

class CorridorState {
  final CorridorStatus status;
  final CorridorData? data;
  final String? errorMessage;

  const CorridorState({
    required this.status,
    this.data,
    this.errorMessage,
  });

  const CorridorState.initial()
      : status = CorridorStatus.initial,
        data = null,
        errorMessage = null;

  CorridorState copyWith({
    CorridorStatus? status,
    CorridorData? data,
    String? errorMessage,
  }) {
    return CorridorState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
