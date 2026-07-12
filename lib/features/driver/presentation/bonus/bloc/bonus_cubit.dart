import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../../core/errors/exceptions.dart';
import '../../../../../core/models/bonus_progress_model.dart';
import '../../../../../core/models/bonus_rule_model.dart';
import '../../../data/repositories/bonus_repository.dart';
import '../../../../../core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

// ─── STATE ──────────────────────────────────────────────────────

/// [BonusState] لم يعد يحمل "قاعدة مختارة" مفردة. كل قاعدة في `rules` تحمل
/// حالتها المستقلة داخل نفسها (BonusRuleModel.status/startedAt/currentValue/
/// targetValue/progressPct/progressId)، قادمة مباشرة من get_my_bonus_progress
/// الجديدة التي تُرجع كل التحديات المتاحة دفعة واحدة بدل قاعدة مختارة، فلا
/// حاجة لأي تخزين محلي (SharedPreferences) بعد اليوم.
///
/// `busyRuleIds` يتتبع أي قاعدة تمر حالياً بعملية شبكية (بدء/طلب استلام)،
/// بحيث يُعطل زر هذه القاعدة بالذات دون تعطيل الشاشة كلها — هذا يحقق
/// متطلب الخطة B.3: "Loading/Error منفصلين لكل عملية (لا تعطيل الشاشة كلها
/// أثناء عملية على قاعدة واحدة)".
///
/// `ruleErrors` يحمل رسالة خطأ مستقلة لكل قاعدة فشلت فيها عملية بدء/طلب
/// استلام، لعرضها فقط في بطاقة تلك القاعدة بدل خطأ عام يغطي الشاشة.
class BonusState extends Equatable {
  final bool isLoading;
  final BonusProgressModel progress;
  final List<BonusRuleModel> rules;
  final List<Map<String, dynamic>> history;
  final Set<String> busyRuleIds;
  final Map<String, String> ruleErrors;
  final String? error;

  const BonusState({
    this.isLoading = true,
    this.progress = const BonusProgressModel(),
    this.rules = const [],
    this.history = const [],
    this.busyRuleIds = const {},
    this.ruleErrors = const {},
    this.error,
  });

  BonusState copyWith({
    bool? isLoading,
    BonusProgressModel? progress,
    List<BonusRuleModel>? rules,
    List<Map<String, dynamic>>? history,
    Set<String>? busyRuleIds,
    Map<String, String>? ruleErrors,
    String? error,
  }) =>
      BonusState(
        isLoading: isLoading ?? this.isLoading,
        progress: progress ?? this.progress,
        rules: rules ?? this.rules,
        history: history ?? this.history,
        busyRuleIds: busyRuleIds ?? this.busyRuleIds,
        ruleErrors: ruleErrors ?? this.ruleErrors,
        error: error,
      );

  @override
  List<Object?> get props => [
        isLoading,
        progress,
        rules,
        history,
        busyRuleIds,
        ruleErrors,
        error,
      ];
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
        _repo.getBonusHistory(driverId),
      ]);

      final progress = results[0] as BonusProgressModel;

      emit(state.copyWith(
        isLoading: false,
        progress: progress,
        rules: progress.bonuses,
        history: results[1] as List<Map<String, dynamic>>,
        busyRuleIds: const {},
        ruleErrors: const {},
      ));
    } catch (e) {
      AppLogger.error('BonusCubit.load: $e');
      emit(state.copyWith(isLoading: false, error: 'errorUnexpected'));
    }
  }

  /// السائق يضغط "ابدأ" على تحدٍ معيّن. هذه العملية فقط تُعطّل (busyRuleIds)
  /// زر تلك القاعدة، لا الشاشة كلها، ثم تُعيد تحميل التقدم كاملاً عند النجاح
  /// لضمان انعكاس الحالة الخادمية الحقيقية (progress_id، started_at) بدقة
  /// بدل تحديث الحالة محلياً فقط.
  Future<void> startChallenge(String ruleId) async {
    if (state.busyRuleIds.contains(ruleId)) return;

    emit(state.copyWith(
      busyRuleIds: {...state.busyRuleIds, ruleId},
      ruleErrors: {...state.ruleErrors}..remove(ruleId),
    ));
    try {
      await _repo.startBonusChallenge(ruleId);
      await load();
    } on AppException catch (e) {
      AppLogger.error('BonusCubit.startChallenge: ${e.message}');
      emit(state.copyWith(
        busyRuleIds: {...state.busyRuleIds}..remove(ruleId),
        ruleErrors: {...state.ruleErrors, ruleId: e.message},
      ));
    } catch (e) {
      AppLogger.error('BonusCubit.startChallenge: $e');
      emit(state.copyWith(
        busyRuleIds: {...state.busyRuleIds}..remove(ruleId),
        ruleErrors: {...state.ruleErrors, ruleId: 'errorUnexpected'},
      ));
    }
  }

  /// السائق يضغط "طلب استلام المكافأة" بعد اكتمال الشرط. نفس نمط العزل
  /// الفردي في [startChallenge] — خطأ على قاعدة واحدة لا يؤثر على بقي
  /// التحديات الأخرى المعروضة.
  Future<void> claimReward(String ruleId, String progressId) async {
    if (state.busyRuleIds.contains(ruleId)) return;

    emit(state.copyWith(
      busyRuleIds: {...state.busyRuleIds, ruleId},
      ruleErrors: {...state.ruleErrors}..remove(ruleId),
    ));
    try {
      await _repo.requestBonusClaim(progressId);
      await load();
    } on AppException catch (e) {
      AppLogger.error('BonusCubit.claimReward: ${e.message}');
      emit(state.copyWith(
        busyRuleIds: {...state.busyRuleIds}..remove(ruleId),
        ruleErrors: {...state.ruleErrors, ruleId: e.message},
      ));
    } catch (e) {
      AppLogger.error('BonusCubit.claimReward: $e');
      emit(state.copyWith(
        busyRuleIds: {...state.busyRuleIds}..remove(ruleId),
        ruleErrors: {...state.ruleErrors, ruleId: 'errorUnexpected'},
      ));
    }
  }
}
