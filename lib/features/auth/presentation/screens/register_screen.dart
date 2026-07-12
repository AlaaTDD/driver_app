import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('signup_screen'),
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: context.textPrimary,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppLocalizations.of(context)!.chooseAccountType,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.chooseRoleDesc,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _AccountTypeCard(
                      key: const ValueKey('register_as_user_card'),
                      icon: Icons.person_rounded,
                      title: AppLocalizations.of(context)!.user,
                      subtitle: AppLocalizations.of(context)!.userDesc,
                      gradientColors: const [
                        AppColors.primary,
                        AppColors.primaryDark
                      ],
                      onTap: () => context.push(AppRoutes.registerUser),
                    ),
                    const SizedBox(height: 16),
                    _AccountTypeCard(
                      key: const ValueKey('register_as_driver_card'),
                      icon: Icons.drive_eta_rounded,
                      title: AppLocalizations.of(context)!.driver,
                      subtitle: AppLocalizations.of(context)!.driverDesc,
                      gradientColors: const [
                        AppColors.success,
                        AppColors.success
                      ],
                      onTap: () => context.push(AppRoutes.registerDriver),
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.alreadyHaveAccount,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            key: const ValueKey('go_to_login_button'),
                            onTap: () => context.pop(),
                            child: Text(
                              AppLocalizations.of(context)!.login,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _AccountTypeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_AccountTypeCard> createState() => _AccountTypeCardState();
}

class _AccountTypeCardState extends State<_AccountTypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(_animCtrl);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animCtrl.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animCtrl.reverse();
  }

  void _handleTapCancel() {
    _animCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.divColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradientColors[0].withValues(alpha: 0.3),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(widget.icon, size: 28, color: AppColors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.gradientColors[0].withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: widget.gradientColors[0],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
