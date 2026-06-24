import 'package:flutter/material.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// Animated shimmer effect for skeleton loading states.
/// Wrap any child widget tree to apply a shimmering gradient.
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              context.cardColor,
              context.elevatedColor,
              context.cardColor,
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(_anim.value, 0),
            end: Alignment(_anim.value + 1, 0),
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Rectangular skeleton placeholder.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Ready-made skeleton for trip card list items.
class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const SkeletonBox(width: 44, height: 44, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 120, height: 14),
                  const SizedBox(height: 8),
                  SkeletonBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 12),
                ],
              ),
            ),
            const SkeletonBox(width: 60, height: 20, radius: 10),
          ],
        ),
      ),
    );
  }
}
