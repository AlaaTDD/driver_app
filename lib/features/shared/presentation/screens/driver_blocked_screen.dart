import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';

/// شاشة حظر السائق — تُعرض عبر [AppRouter.redirect] عند AuthDriverBlocked،
/// بنفس نمط PendingVerificationScreen لكن بدون أي مسار للمتابعة سوى تسجيل
/// الخروج. تعرض سبب الحظر إن توفر (من AuthDriverBlocked.reason، الذي يصل
/// إما من users.blocked_reason الحالي أو drivers_profile.revision_reason
/// حسب مصدر الحظر).
///
/// انظر MASTER_PLAN.md القسم 4، المرحلة ج، البندان 11-12.
class DriverBlockedScreen extends StatelessWidget {
  const DriverBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final authState = context.watch<AuthBloc>().state;
    final reason = authState is AuthDriverBlocked ? authState.reason : null;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // ── Blocked icon ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 64,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.errorUserBlocked,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (reason != null && reason.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const Spacer(),
              // ── Logout button (المسار الوحيد المتاح) ────────────────────
              AppButton(
                text: l.logout,
                onPressed: () {
                  context.read<AuthBloc>().add(SignOutRequested());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
