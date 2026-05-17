import 'package:flutter/material.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool isLast;

  const AppInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? context.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13)),
          ),
          Text(value, style: TextStyle(color: context.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
