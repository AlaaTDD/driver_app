
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool inactive = isLoading || isDisabled;
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: inactive
            ? null
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
        color: inactive ? context.elevatedColor : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: inactive
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: inactive ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: inactive
                          ? context.textDisabled
                          : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
