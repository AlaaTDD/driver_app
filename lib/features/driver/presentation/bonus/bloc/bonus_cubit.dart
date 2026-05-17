import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/bonus_repository.dart';
import '../../../../../services/supabase_service.dart';

// ─── STATE ──────────────────────────────────────────────────────

class BonusState extends Equatable {
  final bool isLoading;
  final Map<String, dynamic> progress;
  final List<Map<String, dynamic>> rules;
  final List<Map<String, dynamic>> history;
  final String? error;

  const BonusState({
    this.isLoading = true,
    this.progress = const {},
    this.rules = const [],
    this.history = const [],
    this.error,
  });

  BonusState copyWith({
    bool? isLoading,
    Map<String, dynamic>? progress,
    List<Map<String, dynamic>>? rules,
    List<Map<String, dynamic>>? history,
    String? error,
  }) =>
      BonusState(
        isLoading: isLoading ?? this.isLoading,
        progress: progress ?? this.progress,
        rules: rules ?? this.rules,
        history: history ?? this.history,
        error: error,
      );

  @override
  List<Object?> get props => [isLoading, progress, rules, history, error];
}

// ─── CUBIT ──────────────────────────────────────────────────────

class BonusCubit extends Cubit<BonusState> {
  final BonusRepository _repo = BonusRepository();

  BonusCubit() : super(const BonusState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final driverId = SupabaseService.currentUser?.id;
      if (driverId == null) {
        emit(state.copyWith(isLoading: false, error: 'errorNotLoggedIn'));
        return;
      }

      final results = await Future.wait([
        _repo.getMyBonusProgress(driverId),
        _repo.getActiveBonusRules(),
        _repo.getBonusHistory(driverId),
      ]);

      emit(state.copyWith(
        isLoading: false,
        progress: results[0] as Map<String, dynamic>,
        rules: results[1] as List<Map<String, dynamic>>,
        history: results[2] as List<Map<String, dynamic>>,
      ));
    } catch (e) {
      debugPrint('❌ BonusCubit.load: $e');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
