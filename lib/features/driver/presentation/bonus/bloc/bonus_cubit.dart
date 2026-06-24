import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/models/bonus_progress_model.dart';
import '../../../../../core/models/bonus_rule_model.dart';
import '../../../data/repositories/bonus_repository.dart';
import '../../../../../core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

// ─── STATE ──────────────────────────────────────────────────────

class BonusState extends Equatable {
  static const Object _unset = Object();

  final bool isLoading;
  final BonusProgressModel progress;
  final List<BonusRuleModel> rules;
  final List<Map<String, dynamic>> history;
  final String? selectedRuleId;
  final String? error;

  const BonusState({
    this.isLoading = true,
    this.progress = const BonusProgressModel(),
    this.rules = const [],
    this.history = const [],
    this.selectedRuleId,
    this.error,
  });

  BonusState copyWith({
    bool? isLoading,
    BonusProgressModel? progress,
    List<BonusRuleModel>? rules,
    List<Map<String, dynamic>>? history,
    Object? selectedRuleId = _unset,
    String? error,
  }) =>
      BonusState(
        isLoading: isLoading ?? this.isLoading,
        progress: progress ?? this.progress,
        rules: rules ?? this.rules,
        history: history ?? this.history,
        selectedRuleId: identical(selectedRuleId, _unset)
            ? this.selectedRuleId
            : selectedRuleId as String?,
        error: error,
      );

  @override
  List<Object?> get props =>
      [isLoading, progress, rules, history, selectedRuleId, error];
}

// ─── CUBIT ──────────────────────────────────────────────────────

class BonusCubit extends Cubit<BonusState> {
  final BonusRepository _repo = BonusRepository();

  BonusCubit() : super(const BonusState());

  String _selectedRuleKey(String driverId) =>
      'driver_bonus_selected_rule_$driverId';

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

      final progress = results[0] as BonusProgressModel;
      final progressRules = progress.bonuses;
      final rules = progressRules.isNotEmpty
          ? progressRules
          : results[1] as List<BonusRuleModel>;
      final prefs = await SharedPreferences.getInstance();
      final savedRuleId = prefs.getString(_selectedRuleKey(driverId));
      final selectedRuleExists = rules.any((rule) => rule.id == savedRuleId);

      emit(state.copyWith(
        isLoading: false,
        progress: progress,
        rules: rules,
        history: results[2] as List<Map<String, dynamic>>,
        selectedRuleId: selectedRuleExists ? savedRuleId : null,
      ));
    } catch (e) {
      AppLogger.error('BonusCubit.load: $e');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> selectRule(String ruleId) async {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedRuleKey(driverId), ruleId);
    emit(state.copyWith(selectedRuleId: ruleId, error: null));
  }
}
