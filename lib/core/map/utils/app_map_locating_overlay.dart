import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// Full-screen locating overlay shown while determining user's GPS position.
/// Replaces the `_buildLocatingScreen()` method duplicated across home screens.
class AppMapLocatingOverlay extends StatelessWidget {
  const AppMapLocatingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              // Intentionally using a simple string since this is a quick
              // transient overlay. Consider using AppLocalizations.locating
              // if the key is available.
              '...',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
