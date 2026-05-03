
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_cached_image.dart';
import '../../../../../core/localization/generated/app_localizations.dart';

class UserDrawer extends StatelessWidget {
  final String userName;
  final String? userAvatar;
  final double userRating;
  final VoidCallback onTripsTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onChatbotTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;

  const UserDrawer({
    super.key,
    required this.userName,
    this.userAvatar,
    required this.userRating,
    required this.onTripsTap,
    required this.onMessagesTap,
    required this.onChatbotTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.bgColor,
      width: 280,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildCompactHeader(context),
          _buildDrawerItem(context, Icons.directions_car, AppLocalizations.of(context)!.myTrips, onTripsTap, AppColors.primary),
          _buildDrawerItem(context, Icons.message, AppLocalizations.of(context)!.messages, onMessagesTap),
          _buildDrawerItem(context, Icons.smart_toy, AppLocalizations.of(context)!.aiAssistant, onChatbotTap),
          _buildDrawerItem(context, Icons.notifications, AppLocalizations.of(context)!.notifications, onNotificationsTap),
          _buildDrawerItem(context, Icons.person, AppLocalizations.of(context)!.editProfile, onProfileTap),
          Divider(color: context.divColor, height: 1),
          _buildDrawerItem(context, Icons.exit_to_app, AppLocalizations.of(context)!.logout, onLogoutTap, AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
          bottom: BorderSide(color: context.divColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.elevatedColor,
            child: userAvatar != null
                ? ClipOval(
                    child: AppCachedImage(
                      imageUrl: userAvatar!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 24,
                    color: context.textSecondary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      userRating.toStringAsFixed(1),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, [
    Color? iconColor,
  ]) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? context.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
