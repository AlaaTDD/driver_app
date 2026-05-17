import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/errors/error_mapper.dart';
import 'bloc/bonus_cubit.dart';

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
                    ElevatedButton(
                      onPressed: () => context.read<BonusCubit>().load(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: Text(l.retry,
                          style: const TextStyle(color: AppColors.white)),
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

  Widget _buildProgressCard(
      BuildContext context, BonusState state, AppLocalizations l) {
    final progress = state.progress;
    final tripsToday = progress['trips_today'] as int? ?? 0;
    final target = progress['target'] as int? ?? 0;
    final bonusAmount = (progress['bonus_amount'] as num?)?.toDouble() ?? 0;
    final progressPct =
        target > 0 ? (tripsToday / target).clamp(0.0, 1.0) : 0.0;

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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.todayProgress,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tripsToday / $target ${l.trips}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (bonusAmount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${bonusAmount.toStringAsFixed(0)} ${l.currencySar}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPct,
              minHeight: 10,
              backgroundColor: AppColors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '${(progressPct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          final name = rule['name_ar'] ?? rule['name'] ?? '';
          final threshold = rule['threshold'] ?? 0;
          final amount = (rule['bonus_amount'] as num?)?.toDouble() ?? 0;
          final trigger = rule['trigger_type'] ?? '';
          final isActive = rule['is_active'] == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.elevatedColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : context.textSecondary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$threshold ${_triggerLabel(trigger, l)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${amount.toStringAsFixed(0)} ${l.currencySar}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
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
                debugPrint(
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
                    '+${amount.toStringAsFixed(0)} ${l.currencySar}',
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

  String _triggerLabel(String trigger, AppLocalizations l) {
    switch (trigger) {
      case 'daily_trips':
        return l.tripsDay;
      case 'weekly_trips':
        return l.tripsWeek;
      case 'rating_threshold':
        return l.ratingStars;
      default:
        return trigger;
    }
  }
}
