import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';
import '../localization/bloc/language_bloc.dart';
import '../localization/generated/app_localizations.dart';
import '../localization/bloc/language_event.dart';
import '../localization/bloc/language_state.dart';
import '../theme/bloc/theme_bloc.dart';
import '../theme/bloc/theme_event.dart';
import '../theme/bloc/theme_state.dart';
import '../../features/auth/domain/entities/user_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppDrawer
// ─────────────────────────────────────────────────────────────────────────────

class AppDrawer extends StatelessWidget {
  final UserEntity? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onTripsTap;
  final VoidCallback? onMessagesTap;
  final VoidCallback? onChatbotTap;
  final VoidCallback? onComplaintsTap;
  final VoidCallback? onLogout;

  const AppDrawer({
    super.key,
    this.user,
    this.onProfileTap,
    this.onTripsTap,
    this.onMessagesTap,
    this.onChatbotTap,
    this.onComplaintsTap,
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
                _NavItem(icon: Icons.person_rounded,      tint: const Color(0xFF6366F1), label: AppLocalizations.of(context)!.profile,   onTap: onProfileTap),
                _NavItem(icon: Icons.route_rounded,       tint: const Color(0xFF10B981), label: AppLocalizations.of(context)!.myTrips,         onTap: onTripsTap),
                _NavItem(icon: Icons.chat_bubble_rounded, tint: const Color(0xFF3B82F6), label: AppLocalizations.of(context)!.messages,        onTap: onMessagesTap),
                _NavItem(icon: Icons.auto_awesome_rounded,tint: const Color(0xFFF59E0B), label: AppLocalizations.of(context)!.aiAssistant,  onTap: onChatbotTap),
                _NavItem(icon: Icons.report_problem_rounded, tint: const Color(0xFFEF4444), label: AppLocalizations.of(context)!.complaints, onTap: onComplaintsTap),
                const SizedBox(height: 4),
                _Divider(),
                const SizedBox(height: 10),
                const _LanguageRow(),
                const SizedBox(height: 8),
                const _ThemeRow(),
                const SizedBox(height: 10),
                _Divider(),
                const SizedBox(height: 4),
                _NavItem(icon: Icons.shield_outlined,      tint: const Color(0xFF8B5CF6), label: AppLocalizations.of(context)!.privacyPolicy, onTap: () {}, small: true),
                _NavItem(icon: Icons.help_outline_rounded, tint: const Color(0xFF64748B), label: AppLocalizations.of(context)!.helpAndSupport, onTap: () {}, small: true),
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

// ─── Header ───────────────────────────────────────────────────────────────────

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
    final name    = user?.name ?? AppLocalizations.of(context)!.userDefault;
    final phone   = user?.phone ?? '';
    final rating  = user?.rating ?? 5.0;
    final top     = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 22, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D2260), Color(0xFF1A3D9A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.8),
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          // Rating
          // FIX M13: Support half-stars — 4.7 shows 4 full + 1 half instead of just 4
          Row(children: [
            ...List.generate(5, (i) {
              final IconData icon;
              final Color color;
              if (i < rating.floor()) {
                icon = Icons.star_rounded;
                color = const Color(0xFFFBBF24);
              } else if (i == rating.floor() && rating - rating.floor() >= 0.25) {
                icon = Icons.star_half_rounded;
                color = const Color(0xFFFBBF24);
              } else {
                icon = Icons.star_outline_rounded;
                color = Colors.white.withValues(alpha: 0.35);
              }
              return Icon(icon, size: 13, color: color);
            }),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(rating.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.phone_rounded, size: 12, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(phone, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback? onTap;
  final bool small;

  const _NavItem({required this.icon, required this.tint, required this.label, this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final sz = small ? 32.0 : 38.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: tint.withValues(alpha: 0.08),
        highlightColor: tint.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(children: [
            Container(
              width: sz, height: sz,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: tint, size: small ? 15 : 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: TextStyle(color: context.textPrimary, fontSize: small ? 13 : 14, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: context.textSecondary.withValues(alpha: 0.35)),
          ]),
        ),
      ),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: context.divColor, height: 1, thickness: 0.8);
}

// ─── Language Row ─────────────────────────────────────────────────────────────

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageBloc, LanguageState>(
      builder: (context, state) {
        final isAr = state is LanguageLoaded ? state.languageCode == 'ar' : true;
        return _ToggleRow(
          icon: Icons.language_rounded, label: AppLocalizations.of(context)!.language,
          leftLabel: AppLocalizations.of(context)!.arabic, rightLabel: AppLocalizations.of(context)!.english, leftActive: isAr,
          onLeft:  () => context.read<LanguageBloc>().add(const ChangeLanguage('ar')),
          onRight: () => context.read<LanguageBloc>().add(const ChangeLanguage('en')),
        );
      },
    );
  }
}

// ─── Theme Row ────────────────────────────────────────────────────────────────

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        final dark = state.isDark;
        return _ToggleRow(
          icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, label: AppLocalizations.of(context)!.appearance,
          leftLabel: AppLocalizations.of(context)!.dark, rightLabel: AppLocalizations.of(context)!.light, leftActive: dark,
          onLeft:  () { if (!dark) context.read<ThemeBloc>().add(ToggleTheme()); },
          onRight: () { if (dark)  context.read<ThemeBloc>().add(ToggleTheme()); },
        );
      },
    );
  }
}

// ─── Toggle Row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label, leftLabel, rightLabel;
  final bool leftActive;
  final VoidCallback onLeft, onRight;

  const _ToggleRow({
    required this.icon, required this.label,
    required this.leftLabel, required this.rightLabel, required this.leftActive,
    required this.onLeft, required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        Icon(icon, size: 17, color: context.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
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
            _Pill(label: leftLabel,  active: leftActive,  onTap: onLeft),
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
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : context.textSecondary,
          fontSize: 11.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }
}

// ─── Logout Button ────────────────────────────────────────────────────────────

class _LogoutBtn extends StatelessWidget {
  final VoidCallback? onLogout;
  const _LogoutBtn({this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        width: double.infinity, height: 48,
        child: ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(AppLocalizations.of(context)!.logout),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

