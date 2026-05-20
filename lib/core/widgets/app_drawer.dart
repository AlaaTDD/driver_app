import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/theme_extensions.dart';
import '../localization/bloc/language_bloc.dart';
import '../localization/generated/app_localizations.dart';
import '../localization/bloc/language_event.dart';
import '../localization/bloc/language_state.dart';
import '../theme/bloc/theme_bloc.dart';
import '../theme/bloc/theme_event.dart';
import '../theme/bloc/theme_state.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/shared/presentation/messages/bloc/messages_cubit.dart';
import '../../features/shared/presentation/messages/bloc/messages_state.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/widgets/app_button.dart';

class AppDrawer extends StatelessWidget {
  final UserEntity? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onWalletTap;
  final VoidCallback? onTripsTap;
  final VoidCallback? onMessagesTap;
  final VoidCallback? onChatbotTap;
  final VoidCallback? onComplaintsTap;
  final VoidCallback? onBonusTap;
  final VoidCallback? onRevisionTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onLogout;

  const AppDrawer({
    super.key,
    this.user,
    this.onProfileTap,
    this.onWalletTap,
    this.onTripsTap,
    this.onMessagesTap,
    this.onChatbotTap,
    this.onComplaintsTap,
    this.onBonusTap,
    this.onRevisionTap,
    this.onPrivacyTap,
    this.onHelpTap,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.76,
      backgroundColor: context.cardColor,
      elevation: 0,
      child: Column(
        children: [
          _Header(user: user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              physics: const BouncingScrollPhysics(),
              children: [
                _NavItem(
                    icon: Icons.person_rounded,
                    tint: AppColors.indigo,
                    label: AppLocalizations.of(context)!.profile,
                    onTap: onProfileTap),
                if (onWalletTap != null)
                  _NavItem(
                      icon: Icons.account_balance_wallet_rounded,
                      tint: AppColors.success,
                      label: AppLocalizations.of(context)!.myWallet,
                      onTap: onWalletTap),
                if (user?.role == 'driver' && onRevisionTap != null)
                  _NavItem(
                      icon: Icons.fact_check_rounded,
                      tint: AppColors.warning,
                      label:
                          AppLocalizations.of(context)!.driverRevisionRequests,
                      onTap: onRevisionTap),
                if (user?.role == 'driver' && onBonusTap != null)
                  _NavItem(
                      icon: Icons.emoji_events_rounded,
                      tint: AppColors.warning,
                      label: AppLocalizations.of(context)!.bonusRewards,
                      onTap: onBonusTap),
                _NavItem(
                    icon: Icons.route_rounded,
                    tint: AppColors.success,
                    label: AppLocalizations.of(context)!.myTrips,
                    onTap: onTripsTap),
                if (user != null)
                  _MessagesNavItem(onMessagesTap: onMessagesTap)
                else
                  _NavItem(
                      icon: Icons.chat_bubble_rounded,
                      tint: AppColors.primary,
                      label: AppLocalizations.of(context)!.messages,
                      onTap: onMessagesTap),
                _NavItem(
                    icon: Icons.auto_awesome_rounded,
                    tint: AppColors.warning,
                    label: AppLocalizations.of(context)!.aiAssistant,
                    onTap: onChatbotTap),
                _NavItem(
                    icon: Icons.report_problem_rounded,
                    tint: AppColors.error,
                    label: AppLocalizations.of(context)!.complaints,
                    onTap: onComplaintsTap),
                const SizedBox(height: 4),
                _Divider(),
                const SizedBox(height: 10),
                const _LanguageRow(),
                const SizedBox(height: 8),
                const _ThemeRow(),
                const SizedBox(height: 10),
                _Divider(),
                const SizedBox(height: 4),
                _NavItem(
                    icon: Icons.shield_outlined,
                    tint: AppColors.purple,
                    label: AppLocalizations.of(context)!.privacyPolicy,
                    onTap: onPrivacyTap,
                    small: true),
                _NavItem(
                    icon: Icons.help_outline_rounded,
                    tint: context.textSecondary,
                    label: AppLocalizations.of(context)!.helpAndSupport,
                    onTap: onHelpTap,
                    small: true),
              ],
            ),
          ),
          _LogoutBtn(onLogout: onLogout),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 14),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserEntity? user;
  const _Header({this.user});

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.length == 1 ? parts[0][0] : '${parts[0][0]}${parts[1][0]}';
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? AppLocalizations.of(context)!.userDefault;
    final phone = user?.phone ?? '';
    final rating = user?.rating ?? 0.0;
    final top = MediaQuery.paddingOf(context).top;
    final avatarUrl = user?.avatarUrl;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 22, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primaryDark,
            AppColors.primary
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.45), width: 1.8),
              image: avatarUrl != null && avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Center(
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(name,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            ...List.generate(5, (i) {
              final IconData icon;
              final Color color;
              if (i < rating.floor()) {
                icon = Icons.star_rounded;
                color = AppColors.warning;
              } else if (i == rating.floor() &&
                  rating - rating.floor() >= 0.25) {
                icon = Icons.star_half_rounded;
                color = AppColors.warning;
              } else {
                icon = Icons.star_outline_rounded;
                color = AppColors.white.withValues(alpha: 0.35);
              }
              return Icon(icon, size: 13, color: color);
            }),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(rating.toStringAsFixed(1),
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.phone_rounded,
                  size: 12, color: AppColors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(phone,
                  style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.75),
                      fontSize: 12.5)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback? onTap;
  final bool small;
  final int? badge;

  const _NavItem(
      {required this.icon,
      required this.tint,
      required this.label,
      this.onTap,
      this.small = false,
      this.badge});

  @override
  Widget build(BuildContext context) {
    final sz = small ? 32.0 : 38.0;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: tint.withValues(alpha: 0.08),
        highlightColor: tint.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(children: [
            Container(
              width: sz,
              height: sz,
              decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: Icon(icon, color: tint, size: small ? 15 : 18)),
                  if (badge != null && badge! > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Center(
                          child: Text(
                            badge! > 99 ? '99+' : badge.toString(),
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: small ? 13 : 14,
                      fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 10, color: context.textSecondary.withValues(alpha: 0.35)),
          ]),
        ),
      ),
    );
  }
}

class _MessagesNavItem extends StatefulWidget {
  final VoidCallback? onMessagesTap;
  const _MessagesNavItem({this.onMessagesTap});

  @override
  State<_MessagesNavItem> createState() => _MessagesNavItemState();
}

class _MessagesNavItemState extends State<_MessagesNavItem> {
  late final MessagesCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = MessagesCubit()..loadConversations();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessagesCubit, MessagesState>(
      bloc: _cubit,
      builder: (context, state) {
        int unreadCount = 0;
        if (state is ConversationsLoaded) {
          for (final conv in state.conversations) {
            unreadCount += (conv['unread_count'] as int?) ?? 0;
          }
        }
        return _NavItem(
          icon: Icons.chat_bubble_rounded,
          tint: AppColors.primary,
          label: AppLocalizations.of(context)!.messages,
          onTap: widget.onMessagesTap,
          badge: unreadCount,
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: context.divColor, height: 1, thickness: 0.8);
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageBloc, LanguageState>(
      builder: (context, state) {
        final isAr =
            state is LanguageLoaded ? state.languageCode == 'ar' : true;
        return _ToggleRow(
          icon: Icons.language_rounded,
          label: AppLocalizations.of(context)!.language,
          leftLabel: AppLocalizations.of(context)!.arabic,
          rightLabel: AppLocalizations.of(context)!.english,
          leftActive: isAr,
          onLeft: () =>
              context.read<LanguageBloc>().add(const ChangeLanguage('ar')),
          onRight: () =>
              context.read<LanguageBloc>().add(const ChangeLanguage('en')),
        );
      },
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        final dark = state.isDark;
        return _ToggleRow(
          icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          label: AppLocalizations.of(context)!.appearance,
          leftLabel: AppLocalizations.of(context)!.dark,
          rightLabel: AppLocalizations.of(context)!.light,
          leftActive: dark,
          onLeft: () {
            if (!dark) context.read<ThemeBloc>().add(ToggleTheme());
          },
          onRight: () {
            if (dark) context.read<ThemeBloc>().add(ToggleTheme());
          },
        );
      },
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label, leftLabel, rightLabel;
  final bool leftActive;
  final VoidCallback onLeft, onRight;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftActive,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        Icon(icon, size: 17, color: context.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          height: 31,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.elevatedColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: context.divColor),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Pill(label: leftLabel, active: leftActive, onTap: onLeft),
            const SizedBox(width: 2),
            _Pill(label: rightLabel, active: !leftActive, onTap: onRight),
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? AppColors.white : context.textSecondary,
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

class _LogoutBtn extends StatelessWidget {
  final VoidCallback? onLogout;
  const _LogoutBtn({this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AppButton(
        text: AppLocalizations.of(context)!.logout,
        variant: AppButtonVariant.danger,
        leadingIcon: Icons.logout_rounded,
        size: AppButtonSize.md,
        onPressed: onLogout,
      ),
    );
  }
}
