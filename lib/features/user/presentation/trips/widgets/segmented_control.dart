import 'package:flutter/material.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';

class SegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;

  const SegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const elevated = AppColors.surfaceElevated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _SegmentButton(
              icon: Icons.pending_actions_rounded,
              label: l.inProgress,
              count: inProgressCount,
              isSelected: selectedIndex == 0,
              onTap: () => onIndexChanged(0),
            ),
            _SegmentButton(
              icon: Icons.check_circle_rounded,
              label: l.completed,
              count: completedCount,
              isSelected: selectedIndex == 1,
              onTap: () => onIndexChanged(1),
            ),
            _SegmentButton(
              icon: Icons.cancel_rounded,
              label: l.cancelled,
              count: cancelledCount,
              isSelected: selectedIndex == 2,
              onTap: () => onIndexChanged(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primary;
    const card = AppColors.surface;
    const t2 = AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [blue, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.white : t2),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.white : t2,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.white.withValues(alpha: 0.2)
                        : card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? AppColors.white : t2,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
