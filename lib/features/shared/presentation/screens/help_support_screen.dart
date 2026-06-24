import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  bool _isAr(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _t(BuildContext context, String ar, String en) =>
      _isAr(context) ? ar : en;

  String _role(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.role : 'user';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDriver = _role(context) == 'driver';
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text(l.helpAndSupport),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _HeroPanel(
            title: _t(context, 'كيف نقدر نساعدك؟', 'How can we help?'),
            subtitle: _t(
              context,
              'اختر أسرع قناة مناسبة للمشكلة. المحادثات والشكاوى محفوظة داخل حسابك للمتابعة.',
              'Choose the best support channel. Chats and complaints are saved on your account for follow-up.',
            ),
          ),
          const SizedBox(height: 16),
          _SupportAction(
            icon: Icons.auto_awesome_rounded,
            tint: AppColors.primary,
            title: l.aiAssistant,
            subtitle: _t(
              context,
              'اسأل عن الرحلات، الحساب، المدفوعات، أو مشاكل التطبيق.',
              'Ask about trips, account, payments, or app issues.',
            ),
            onTap: () => context.push(
              isDriver ? AppRoutes.driverChatbot : AppRoutes.userChatbot,
            ),
          ),
          _SupportAction(
            icon: Icons.report_problem_rounded,
            tint: AppColors.error,
            title: l.complaints,
            subtitle: _t(
              context,
              'سجل شكوى رسمية لمشكلة في رحلة أو حساب أو دفع.',
              'File an official complaint for a trip, account, or payment issue.',
            ),
            onTap: () => context.push(
              isDriver ? AppRoutes.driverComplaints : AppRoutes.userComplaints,
            ),
          ),
          _SupportAction(
            icon: Icons.chat_bubble_rounded,
            tint: AppColors.info,
            title: l.messages,
            subtitle: _t(
              context,
              'راجع محادثاتك المرتبطة بالرحلات.',
              'Review your trip-related conversations.',
            ),
            onTap: () => context.push(
              isDriver ? AppRoutes.driverMessages : AppRoutes.userMessages,
            ),
          ),
          const SizedBox(height: 12),
          _FaqSection(
            title: _t(context, 'أسئلة سريعة', 'Quick Questions'),
            items: [
              (
                _t(context, 'تأخر السائق أو المستخدم',
                    'Driver or rider is late'),
                _t(
                  context,
                  'افتح تفاصيل الرحلة وتواصل من الرسائل، أو سجل شكوى إذا انتهت الرحلة بمشكلة.',
                  'Open trip details and use messages, or file a complaint if the trip ended with an issue.',
                ),
              ),
              (
                _t(context, 'مشكلة في الرصيد أو الدفع',
                    'Wallet or payment issue'),
                _t(
                  context,
                  'راجع المحفظة أولا، ثم استخدم الشكاوى مع رقم الرحلة إن وجد.',
                  'Check the wallet first, then submit a complaint with the trip number when available.',
                ),
              ),
              (
                _t(context, 'تحديث صورة الملف الشخصي', 'Update profile photo'),
                _t(
                  context,
                  'افتح الملف الشخصي واضغط على الصورة، ثم اختر الكاميرا أو المعرض.',
                  'Open your profile, tap the photo, then choose camera or gallery.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeroPanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded,
              color: AppColors.info, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.textSecondary,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportAction({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divColor),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tint, size: 21),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12.5,
              height: 1.25,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: context.textSecondary.withValues(alpha: 0.45),
          size: 14,
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  final String title;
  final List<(String, String)> items;

  const _FaqSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
