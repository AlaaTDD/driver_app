import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// Floating hint pill at the top of the corridor picker — shows the
/// current step instruction.
class CorridorHintPill extends StatelessWidget {
  final String hint;

  const CorridorHintPill({
    super.key,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.26),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.white.withValues(alpha: 0.90),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}
