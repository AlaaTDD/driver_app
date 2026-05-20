import 'package:flutter/material.dart';

/// Small legend indicator used in the corridor picker map overlay.
class LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const LegendChip({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]);
}
