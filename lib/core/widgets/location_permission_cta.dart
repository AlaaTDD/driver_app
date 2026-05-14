import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/location_permission_cubit.dart';
import '../services/location_permission_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';
import '../localization/generated/app_localizations.dart';

/// A reusable CTA widget that replaces normal UI when location is blocked.
///
/// Adapts its message and action based on:
/// - `denied` → "Enable Location" (triggers OS dialog)
/// - `permanentlyDenied` / `restricted` → "Go to Settings" (opens app settings)
/// - `serviceDisabled` → "Turn On Location Services" (opens device settings)
class LocationPermissionCta extends StatelessWidget {
  /// Optional callback when permission is granted after user action.
  final VoidCallback? onGranted;

  /// Visual variant — 'card' for user bottom sheet, 'button' for driver GO.
  final LocationCtaVariant variant;

  const LocationPermissionCta({
    super.key,
    this.onGranted,
    this.variant = LocationCtaVariant.card,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LocationPermissionCubit, LocationPermissionState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.isGranted,
      listener: (context, state) {
        onGranted?.call();
      },
      builder: (context, state) {
        if (state.isChecking) {
          return const SizedBox.shrink();
        }

        final l = AppLocalizations.of(context)!;
        final config = _getConfig(state.status, l);

        if (variant == LocationCtaVariant.button) {
          return _buildButtonVariant(context, config, state);
        }

        return _buildCardVariant(context, config, state);
      },
    );
  }

  /// Card variant — replaces the search bar + promo in user home bottom sheet.
  Widget _buildCardVariant(
    BuildContext context,
    _CtaConfig config,
    LocationPermissionState state,
  ) {
    return GestureDetector(
      onTap: () => context.read<LocationPermissionCubit>().handleAction(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              config.color.withValues(alpha: 0.12),
              config.color.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: config.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                config.icon,
                color: config.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    config.subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: config.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    config.actionIcon,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    config.actionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Button variant — replaces the GO button on driver home.
  Widget _buildButtonVariant(
    BuildContext context,
    _CtaConfig config,
    LocationPermissionState state,
  ) {
    return GestureDetector(
      onTap: () => context.read<LocationPermissionCubit>().handleAction(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF59E0B), // amber
              const Color(0xFFD97706), // amber dark
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                config.buttonLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CtaConfig _getConfig(LocationStatus status, AppLocalizations l) {
    switch (status) {
      case LocationStatus.denied:
        return _CtaConfig(
          icon: Icons.location_off_rounded,
          title: l.locationDeniedTitle,
          subtitle: l.locationDeniedSubtitle,
          actionText: l.locationEnableAction,
          actionIcon: Icons.location_on_rounded,
          buttonLabel: l.locationCtaShort,
          color: AppColors.warning,
        );
      case LocationStatus.permanentlyDenied:
      case LocationStatus.restricted:
        return _CtaConfig(
          icon: Icons.settings_rounded,
          title: l.locationPermanentlyDeniedTitle,
          subtitle: l.locationPermanentlyDeniedSubtitle,
          actionText: l.locationGoToSettings,
          actionIcon: Icons.open_in_new_rounded,
          buttonLabel: l.locationCtaShort,
          color: AppColors.error,
        );
      case LocationStatus.serviceDisabled:
        return _CtaConfig(
          icon: Icons.gps_off_rounded,
          title: l.locationServiceDisabledTitle,
          subtitle: l.locationServiceDisabledSubtitle,
          actionText: l.locationGoToSettings,
          actionIcon: Icons.open_in_new_rounded,
          buttonLabel: l.locationCtaShort,
          color: AppColors.error,
        );
      default:
        return _CtaConfig(
          icon: Icons.location_off_rounded,
          title: l.locationDeniedTitle,
          subtitle: l.locationDeniedSubtitle,
          actionText: l.locationEnableAction,
          actionIcon: Icons.location_on_rounded,
          buttonLabel: l.locationCtaShort,
          color: AppColors.warning,
        );
    }
  }
}

enum LocationCtaVariant { card, button }

class _CtaConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;
  final IconData actionIcon;
  final String buttonLabel;
  final Color color;

  const _CtaConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.actionIcon,
    required this.buttonLabel,
    required this.color,
  });
}
