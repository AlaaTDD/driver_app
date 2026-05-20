import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/bonus_repository.dart';
import '../../../../../services/supabase_service.dart';

// ─── STATE ──────────────────────────────────────────────────────

class BonusState extends Equatable {
  static const Object _unset = Object();

  final bool isLoading;
  final Map<String, dynamic> progress;
  final List<Map<String, dynamic>> rules;
  final List<Map<String, dynamic>> history;
  final String? selectedRuleId;
  final String? error;

  const BonusState({
    this.isLoading = true,
    this.progress = const {},
    this.rules = const [],
    this.history = const [],
    this.selectedRuleId,
    this.error,
  });

  BonusState copyWith({
    bool? isLoading,
    Map<String, dynamic>? progress,
    List<Map<String, dynamic>>? rules,
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

  String? _ruleId(Map<String, dynamic> rule) =>
      (rule['rule_id'] ?? rule['id'])?.toString();

  List<Map<String, dynamic>> _progressRules(Map<String, dynamic> progress) {
    final bonuses = progress['bonuses'];
    if (bonuses is! List) return const [];
    return bonuses
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

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

      final progress = results[0] as Map<String, dynamic>;
      final progressRules = _progressRules(progress);
      final rules = progressRules.isNotEmpty
          ? progressRules
          : results[1] as List<Map<String, dynamic>>;
      final prefs = await SharedPreferences.getInstance();
      final savedRuleId = prefs.getString(_selectedRuleKey(driverId));
      final selectedRuleExists =
          rules.any((rule) => _ruleId(rule) == savedRuleId);

      emit(state.copyWith(
        isLoading: false,
        progress: progress,
        rules: rules,
        history: results[2] as List<Map<String, dynamic>>,
        selectedRuleId: selectedRuleExists ? savedRuleId : null,
      ));
    } catch (e) {
      debugPrint('❌ BonusCubit.load: $e');
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
