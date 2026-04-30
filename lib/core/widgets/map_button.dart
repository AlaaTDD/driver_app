// lib/core/widgets/map_button.dart
import 'package:flutter/material.dart';
import '../theme/theme_extensions.dart';

/// Shared floating button for map overlays.
/// Used identically on both user and driver home screens.
class MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double borderRadius;

  const MapButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: context.textPrimary, size: 21),
      ),
    );
  }
}
