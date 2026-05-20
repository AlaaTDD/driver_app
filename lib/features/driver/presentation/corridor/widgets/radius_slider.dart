import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// Radius slider for corridor origin/destination zones.
class RadiusSlider extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const RadiusSlider({
    super.key,
    required this.label,
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(children: [
      SizedBox(
        width: 110,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? null : AppColors.grey)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: enabled ? color : AppColors.grey,
            inactiveTrackColor: AppColors.grey.withValues(alpha: 0.2),
            thumbColor: enabled ? color : AppColors.grey,
            overlayColor: color.withValues(alpha: 0.1),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 0.5).round(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(l.kmValue(value.toStringAsFixed(1)),
            style: TextStyle(
                fontSize: 10,
                color: enabled ? color : AppColors.grey,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.end),
      ),
    ]);
  }
}
