import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// Origin / Destination selection chip for the corridor picker panel.
class PointChip extends StatelessWidget {
  final bool isDone;
  final bool isActive;
  final Color color;
  final IconData icon;
  final String label;
  final String? address;
  final VoidCallback onTap;

  const PointChip({
    super.key,
    required this.isDone,
    required this.isActive,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDone
                ? color.withValues(alpha: 0.12)
                : isActive
                    ? color.withValues(alpha: 0.08)
                    : AppColors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone || isActive
                  ? color.withValues(alpha: isDone ? 0.50 : 0.38)
                  : AppColors.grey.withValues(alpha: 0.2),
              width: isActive ? 1.4 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                color: isDone || isActive ? color : AppColors.grey, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              isDone || isActive ? color : AppColors.grey)),
                  if (address != null)
                    Text(address!,
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)
                  else
                    Text(isActive ? l.tapMap : l.noData,
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.grey)),
                ])),
            if (isDone) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded,
                  size: 15, color: color.withValues(alpha: 0.85)),
            ],
          ]),
        ),
      ),
    );
  }
}
