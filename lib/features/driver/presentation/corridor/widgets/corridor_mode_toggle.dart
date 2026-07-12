import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/features/driver/data/repositories/corridor_repository.dart';

/// Segmented toggle letting the driver choose between "points" (two
/// independent radius circles) and "line" (actual route polyline with a
/// fixed width) corridor modes.
class CorridorModeToggle extends StatelessWidget {
  final CorridorMode mode;
  final bool enabled;
  final ValueChanged<CorridorMode> onChanged;

  const CorridorModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: _Segment(
            label: l.corridorModePoints,
            icon: Icons.adjust_rounded,
            isSelected: mode == CorridorMode.points,
            enabled: enabled,
            onTap: () => onChanged(CorridorMode.points),
          ),
        ),
        Expanded(
          child: _Segment(
            label: l.corridorModeLine,
            icon: Icons.timeline_rounded,
            isSelected: mode == CorridorMode.line,
            enabled: enabled,
            onTap: () => onChanged(CorridorMode.line),
          ),
        ),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: isSelected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 15,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.grey.withValues(alpha: enabled ? 1.0 : 0.5)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.grey.withValues(alpha: enabled ? 1.0 : 0.5))),
        ]),
      ),
    );
  }
}
