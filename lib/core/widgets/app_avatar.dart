import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/widgets/app_cached_image.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name; // يُستخدم لعرض الحرف الأول إذا لا صورة
  final double size;
  final Color? backgroundColor;
  final bool showOnlineIndicator;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.backgroundColor,
    this.showOnlineIndicator = false,
  });

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? context.elevatedColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? AppCachedImage(imageUrl: imageUrl!, width: size, height: size)
              : Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        if (showOnlineIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: context.bgColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
