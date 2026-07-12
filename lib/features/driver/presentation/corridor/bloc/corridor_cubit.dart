import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapix/features/driver/data/repositories/corridor_repository.dart';

part 'corridor_state.dart';

class CorridorCubit extends Cubit<CorridorState> {
  final CorridorRepository _repo;
  final String _driverId;

  CorridorCubit({required CorridorRepository repo, required String driverId})
      : _repo = repo,
        _driverId = driverId,
        super(const CorridorState.initial());

  Future<void> load() async {
    emit(state.copyWith(status: CorridorStatus.loading));
    try {
      final data = await _repo.loadCorridor(_driverId);
      if (isClosed) return;
      emit(state.copyWith(status: CorridorStatus.loaded, data: data));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          status: CorridorStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> save(CorridorData data) async {
    emit(state.copyWith(status: CorridorStatus.saving));
    try {
      await _repo.saveCorridor(_driverId, data);
      if (isClosed) return;
      emit(state.copyWith(status: CorridorStatus.saved, data: data));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          status: CorridorStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> clear() async {
    emit(state.copyWith(status: CorridorStatus.saving));
    try {
      await _repo.clearCorridor(_driverId);
      if (isClosed) return;
      emit(const CorridorState.initial());
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          status: CorridorStatus.error, errorMessage: e.toString()));
    }
  }
}
