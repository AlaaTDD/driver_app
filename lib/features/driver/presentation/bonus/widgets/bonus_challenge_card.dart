import 'package:flutter/material.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import '../../../../../core/models/bonus_rule_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/price_formatter.dart';
import '../../../../../core/errors/error_mapper.dart';
import '../../../../../core/widgets/app_button.dart';

/// بطاقة تحدٍ واحد في شاشة الحوافز. كل بطاقة مستقلة تماماً عن غيرها:
/// حالتها (notStarted/active/completed/claim_pending/claimed) وزر تفاعلها
/// وحالة التحميل/الخطأ الخاصة بها تأتي جميعاً من [rule] ومن [isBusy]/
/// [errorMessage] المُمرَّرين من الشاشة الأب — البطاقة نفسها بلا حالة داخلية.
///
/// استُخرجت من bonus_screen.dart (كانت جزءاً من _buildRulesSection) لتفادي
/// تجاوز حد الـ 500 سطر لكل ملف Dart، ولأن منطق الحالة الخمس الجديد
/// (بدل "مُختار/غير مُختار" القديم) أعقد بما يكفي ليستحق ملفاً مستقلاً.
class BonusChallengeCard extends StatelessWidget {
  final BonusRuleModel rule;
  final bool isBusy;
  final String? errorMessage;
  final VoidCallback onStart;
  final VoidCallback onClaim;

  const BonusChallengeCard({
    super.key,
    required this.rule,
    required this.isBusy,
    required this.onStart,
    required this.onClaim,
    this.errorMessage,
  });

  /// نص التصنيف حسب trigger_type: يومي/أسبوعي/تقييم — من مفاتيح الترجمة
  /// الرسمية بدل نص عام، لتمييز طبيعة كل تحدٍ (بند 1: عرض التقييم بدل عدد
  /// الرحلات عند rating_threshold تحديداً).
  String _triggerLabel(AppLocalizations l) {
    switch (rule.triggerType) {
      case 'daily_trips':
        return l.tripsDay;
      case 'weekly_trips':
        return l.tripsWeek;
      case 'rating_threshold':
        return l.ratingStars;
      default:
        return rule.triggerType;
    }
  }

  /// نص "الهدف" أسفل اسم القاعدة: يعرض التقييم المطلوب لو rating_threshold،
  /// أو عدد الرحلات لغير ذلك — بدل "عدد رحلات" الثابت في كل الحالات سابقاً.
  String _targetLabel(BuildContext context, AppLocalizations l) {
    if (rule.triggerType == 'rating_threshold') {
      final target = rule.targetValue > 0
          ? rule.targetValue
          : (rule.minRating ?? 0);
      final current = rule.status == 'not_started' ? 0.0 : rule.currentValue;
      return '⭐ ${current.toStringAsFixed(1)} / ${target.toStringAsFixed(1)}';
    }
    final target = rule.targetValue > 0 ? rule.targetValue : rule.threshold;
    final current = rule.status == 'not_started' ? 0 : rule.currentValue.toInt();
    return '$current / ${target.toInt()} · ${_triggerLabel(l)}';
  }

  Color _accentColor() {
    switch (rule.status) {
      case 'completed':
        return AppColors.success;
      case 'claim_pending':
        return AppColors.warning;
      case 'claimed':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  /// شارة نصية صغيرة تُعرض بدل الزر عند claim_pending/claimed، حيث لا يوجد
  /// فعل إضافي يمكن للسائق اتخاذه — فقط حالة يجب معرفتها.
  Widget? _statusBadge(BuildContext context, AppLocalizations l) {
    switch (rule.status) {
      case 'claim_pending':
        return _badge(
          l.bonusClaimPending,
          AppColors.warning,
          Icons.hourglass_top_rounded,
        );
      case 'claimed':
        return _badge(
          l.bonusClaimReceived,
          AppColors.success,
          Icons.check_circle_rounded,
        );
      default:
        return null;
    }
  }

  Widget _badge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  /// زر الفعل الرئيسي: ابدأ (not_started) / معطَّل مع مؤشر تحميل (active) /
  /// طلب استلام المكافأة (completed). عند claim_pending/claimed لا يُعرض زر
  /// إطلاقاً — البادج أعلاه يكفي.
  Widget? _actionButton(BuildContext context, AppLocalizations l) {
    switch (rule.status) {
      case 'not_started':
        return AppButton(
          text: l.bonusStartChallenge,
          size: AppButtonSize.sm,
          width: null,
          isLoading: isBusy,
          leadingIcon: Icons.play_arrow_rounded,
          onPressed: isBusy ? null : onStart,
        );
      case 'active':
        return AppButton(
          text: l.bonusActive,
          size: AppButtonSize.sm,
          width: null,
          isDisabled: true,
          variant: AppButtonVariant.secondary,
          leadingIcon: Icons.timelapse_rounded,
          onPressed: null,
        );
      case 'completed':
        return AppButton(
          text: l.bonusRequestClaim,
          size: AppButtonSize.sm,
          width: null,
          isLoading: isBusy,
          leadingIcon: Icons.redeem_rounded,
          onPressed: isBusy ? null : onClaim,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = rule.nameAr ?? rule.name;
    final progressPct = rule.status == 'not_started'
        ? 0.0
        : (rule.progressPct / 100).clamp(0.0, 1.0);
    final accent = _accentColor();
    final badge = _statusBadge(context, l);
    final action = _actionButton(context, l);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rule.triggerType == 'rating_threshold'
                      ? Icons.star_rounded
                      : Icons.local_fire_department_rounded,
                  color: accent,
                  size: 20,
                ),
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
                      _targetLabel(context, l),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        minHeight: 7,
                        backgroundColor: accent.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${PriceFormatter.displayCompactWithCurrency(context, rule.bonusAmount)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (badge != null) badge else if (action != null) action,
                ],
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ErrorMapper.getErrorMessage(context, errorMessage!),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
