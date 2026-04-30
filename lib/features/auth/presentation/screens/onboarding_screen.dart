// lib/features/auth/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class _PageData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

List<_PageData> _getPages(AppLocalizations l) => [
  _PageData(
    icon: Icons.hail_rounded,
    title: l.smartRideService,
    subtitle: l.smartRideDesc,
  ),
  _PageData(
    icon: Icons.gps_fixed_rounded,
    title: l.realTimeTracking,
    subtitle: l.realTimeTrackingDesc,
  ),
  _PageData(
    icon: Icons.security_rounded,
    title: l.safeAndReliable,
    subtitle: l.safeAndReliableDesc,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  int _prevPage = 0;
  // +1 = forward (swipe left / tap next), -1 = backward (swipe right)
  int _navDirection = 1;

  late final AnimationController _anim;
  // Camera pans the icon panorama (0=page0, 1=page1, 2=page2)
  late final Animation<double> _cameraAnim;
  // Text crossfade + parallax slide
  late final Animation<double> _outOpacity;
  late final Animation<double> _inOpacity;
  late final Animation<Offset> _outTextSlide;
  late final Animation<Offset> _inTextSlide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..value = 1.0;

    final out = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.0, 0.50, curve: Curves.easeIn),
    );
    final inn = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOutCubic),
    );

    // Camera: full-range smooth curve for panorama panning
    _cameraAnim   = CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic);
    _outOpacity   = Tween(begin: 1.0, end: 0.0).animate(out);
    _outTextSlide = Tween(begin: Offset.zero, end: const Offset(-0.20, 0)).animate(out);
    _inOpacity    = inn;
    _inTextSlide  = Tween(begin: const Offset(0.20, 0), end: Offset.zero).animate(inn);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Navigate by [delta]: +1 = next, -1 = previous.
  void _navigate(int delta) {
    if (_anim.isAnimating) return;
    final target = _currentPage + delta;
    final pages = _getPages(AppLocalizations.of(context)!);
    if (target >= pages.length) {
      context.go(AppRoutes.login);
      return;
    }
    if (target < 0) return;
    _navDirection = delta;
    setState(() {
      _prevPage = _currentPage;
      _currentPage = target;
    });
    _anim.forward(from: 0.0);
  }

  void _skip() => context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final pages = _getPages(AppLocalizations.of(context)!);
    final isLast = _currentPage == pages.length - 1;
    final dir = _navDirection.toDouble(); // used by text slide

    return Scaffold(
      backgroundColor: context.bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (d) {
          final v = d.velocity.pixelsPerSecond.dx;
          if (v < -350) _navigate(1);
          else if (v > 350) _navigate(-1);
        },
        child: Stack(
          children: [
            // ── Atmospheric blue glow (static) ────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: size.height * 0.68,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.85,
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.13),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // ── Content ───────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // ── Skip — top right ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedOpacity(
                          opacity: isLast ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: TextButton(
                            onPressed: isLast ? null : _skip,
                            style: TextButton.styleFrom(
                              foregroundColor: context.textSecondary,
                              minimumSize: const Size(0, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Text(AppLocalizations.of(context)!.skip,
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Icon panorama — camera pans across 3 connected icons ──
                  Expanded(
                    flex: 5,
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, _) {
                          // Camera position: 0 = page0, 1 = page1, 2 = page2
                          final camPos = _prevPage +
                              (_currentPage - _prevPage) * _cameraAnim.value;
                          return SizedBox.expand(
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: List.generate(pages.length, (i) {
                                final dx = (i - camPos) * 240.0;
                                final dist = (i.toDouble() - camPos).abs();
                                final scale = (1.0 - dist * 0.14).clamp(0.0, 1.0);
                                final opacity = (1.0 - dist * 0.7).clamp(0.0, 1.0);
                                return Transform.translate(
                                  offset: Offset(dx, 0),
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: _IconDisplay(icon: pages[i].icon),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // ── Text (near parallax layer — moves faster) ─────────
                  Expanded(
                    flex: 4,
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) {
                        final tx = !_anim.isCompleted;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 34),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              if (tx)
                                Opacity(
                                  opacity: _outOpacity.value,
                                  child: FractionalTranslation(
                                    translation: Offset(
                                        _outTextSlide.value.dx * dir, 0),
                                    child:
                                        _TextBlock(page: pages[_prevPage]),
                                  ),
                                ),
                              Opacity(
                                opacity: _inOpacity.value,
                                child: FractionalTranslation(
                                  translation: Offset(
                                      _inTextSlide.value.dx * dir, 0),
                                  child: _TextBlock(
                                      page: pages[_currentPage]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // ── Bottom row: dots LEFT · button RIGHT ──────────────
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(32, 0, 32, bottomPad + 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Dots
                        Row(
                          children: List.generate(
                            pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _currentPage ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _currentPage
                                    ? AppColors.primary
                                    : context.divColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        // Circular next button
                        _CircleButton(
                          isLast: isLast,
                          onPressed: () => _navigate(1),
                        ),
                      ],
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
}

// ── Glowing icon ──────────────────────────────────────────────────────────────
class _IconDisplay extends StatelessWidget {
  final IconData icon;
  const _IconDisplay({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 210, height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.05),
          ),
        ),
        Container(
          width: 168, height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.09),
          ),
        ),
        Container(
          width: 128, height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.primaryTint,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.32),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 52,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, size: 56, color: AppColors.primary),
        ),
      ],
    );
  }
}

// ── Circular next / finish button ─────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final bool isLast;
  final VoidCallback onPressed;
  const _CircleButton({required this.isLast, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                key: ValueKey(isLast),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Text block ────────────────────────────────────────────────────────────────
class _TextBlock extends StatelessWidget {
  final _PageData page;
  const _TextBlock({required this.page});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          page.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            height: 1.82,
          ),
        ),
      ],
    );
  }
}
