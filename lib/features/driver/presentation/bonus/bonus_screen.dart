import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/widgets/app_button.dart';
import 'bloc/bonus_cubit.dart';
import 'widgets/bonus_challenge_card.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverBonusScreen extends StatelessWidget {
  const DriverBonusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => BonusCubit()..load(),
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          elevation: 0,
          centerTitle: true,
          title: Text(
            l.bonusRewards,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: context.textPrimary),
        ),
        body: BlocBuilder<BonusCubit, BonusState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: context.textSecondary),
                    const SizedBox(height: 12),
                    Text(ErrorMapper.getErrorMessage(context, state.error!),
                        style: TextStyle(color: context.textSecondary)),
                    const SizedBox(height: 16),
                    AppButton(
                      text: l.retry,
                      onPressed: () => context.read<BonusCubit>().load(),
                      size: AppButtonSize.sm,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<BonusCubit>().load(),
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProgressCard(context, state, l),
                  const SizedBox(height: 20),
                  _buildRulesSection(context, state, l),
                  const SizedBox(height: 20),
                  _buildHistorySection(context, state, l),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ملخص عام لكل التحديات، بدل تفاصيل قاعدة "مختارة" واحدة كما كان سابقاً.
  /// يعرض: عدد التحديات النشطة/المكتملة إجمالاً، وأقرب حافز جاهز للاستلام
  /// إن وُجد (لجذب انتباه السائق إليه دون الحاجة للتمرير للأسفل).
  Widget _buildProgressCard(
      BuildContext context, BonusState state, AppLocalizations l) {
    final rules = state.rules;
    final activeCount =
        rules.where((r) => r.status == 'active').length;
    final readyToClaimCount =
        rules.where((r) => r.status == 'completed').length;
    final totalCount = rules.length;

    final title = totalCount == 0
        ? l.bonusNoneAvailable
        : readyToClaimCount > 0
            ? l.bonusReadyToClaimTitle
            : activeCount > 0
                ? l.bonusKeepGoing
                : l.bonusStartFirstChallenge;

    final subtitle = totalCount == 0
        ? l.bonusCheckBackLater
        : l.bonusSummaryStats(activeCount, readyToClaimCount, totalCount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigo, AppColors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              readyToClaimCount > 0
                  ? Icons.redeem_rounded
                  : Icons.emoji_events_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// يعرض كل قاعدة كـ [BonusChallengeCard] مستقلة بحالتها الخاصة، بدل الاكتفاء
  /// بمهمة واحدة "مختارة" كما كان سابقاً — يحل بند 5 من المهمة مباشرة.
  Widget _buildRulesSection(
      BuildContext context, BonusState state, AppLocalizations l) {
    if (state.rules.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rule_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              l.bonusRules,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...state.rules.map((rule) {
          final ruleId = rule.id;
          if (ruleId.isEmpty) return const SizedBox.shrink();

          return BonusChallengeCard(
            key: ValueKey(ruleId),
            rule: rule,
            isBusy: state.busyRuleIds.contains(ruleId),
            errorMessage: state.ruleErrors[ruleId],
            onStart: () => context.read<BonusCubit>().startChallenge(ruleId),
            onClaim: rule.progressId == null
                ? () {}
                : () => context
                    .read<BonusCubit>()
                    .claimReward(ruleId, rule.progressId!),
          );
        }),
      ],
    );
  }

  Widget _buildHistorySection(
      BuildContext context, BonusState state, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              l.bonusHistory,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.elevatedColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 48,
                    color: context.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  l.noBonusYet,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...state.history.map((award) {
            final amount = (award['bonus_amount'] as num?)?.toDouble() ?? 0;
            final ruleName = (award['bonus_rules'] as Map?)?['name_ar'] ??
                (award['bonus_rules'] as Map?)?['name'] ??
                '';
            final dateStr = award['awarded_at'] as String?;
            String formatted = '';
            if (dateStr != null) {
              try {
                formatted = DateFormat('yyyy/MM/dd HH:mm')
                    .format(DateTime.parse(dateStr).toLocal());
              } catch (e, st) {
                AppLogger.debug(
                    '⚠️ DriverBonusScreen: invalid awarded_at "$dateStr": $e\n$st');
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.elevatedColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ruleName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        if (formatted.isNotEmpty)
                          Text(
                            formatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '+${PriceFormatter.displayCompactWithCurrency(context, amount)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

}
