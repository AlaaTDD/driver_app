import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class BottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const BottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class CustomAnimatedBottomNav extends StatelessWidget {
  final List<BottomNavItem> items;
  final ValueChanged<int> onTap;

  /// Widget displayed in the FAB notch (optional)
  final Widget? floatingActionButton;

  final Color backgroundColor;
  final Color itemColor;
  final Color notchColor;
  final double height;
  final double iconSize;
  final double notchRadius;
  final double gapWidth;
  final bool showLabels;
  final double elevation;

  const CustomAnimatedBottomNav({
    super.key,
    required this.items,
    required this.onTap,
    this.floatingActionButton,
    this.backgroundColor = Colors.white,
    this.itemColor = const Color(0xFF9E9E9E),
    this.notchColor = const Color(0xFF6C63FF),
    this.height = 72,
    this.iconSize = 26,
    this.notchRadius = 38,
    this.gapWidth = 80,
    this.showLabels = true,
    this.elevation = 12,
  }) : assert(
          items.length >= 2 && items.length <= 5,
          'Items must be between 2 and 5',
        );

  bool get _hasFab => floatingActionButton != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height + notchRadius,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ── Bar ──────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height,
            child: Material(
              elevation: elevation,
              shadowColor: Colors.black.withOpacity(0.1),
              color: Colors.transparent,
              child: CustomPaint(
                painter: _NotchPainter(
                  color: backgroundColor,
                  notchRadius: _hasFab ? notchRadius : 0,
                  gapWidth: _hasFab ? gapWidth : 0,
                ),
                child: _buildItems(),
              ),
            ),
          ),

          // ── FAB ───────────────────────────────
          if (_hasFab)
            Positioned(
              // Back to original: FAB sits inside the notch (90% depth)
              bottom: height - notchRadius * 0.9,
              child: _buildFab(),
            ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      width: notchRadius * 2 - 12,   // slightly smaller than notch opening for a visible rim
      height: notchRadius * 2 - 12,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: notchColor,
        boxShadow: notchColor.alpha > 0
            ? [
                BoxShadow(
                  color: notchColor.withOpacity(0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: floatingActionButton,
    );
  }

  Widget _buildItems() {
    final List<Widget> children = [];

    if (_hasFab) {
      final half = items.length ~/ 2;
      final leftItems = items.sublist(0, half);
      final rightItems = items.sublist(half);

      children.addAll(_buildSide(leftItems, 0));
      children.add(SizedBox(width: gapWidth)); // gap for notch
      children.addAll(_buildSide(rightItems, half));
    } else {
      children.addAll(_buildSide(items, 0));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    );
  }

  List<Widget> _buildSide(List<BottomNavItem> sideItems, int indexOffset) {
    return List.generate(sideItems.length, (i) {
      final globalIndex = i + indexOffset;
      return Expanded(
        child: _NavItemWidget(
          item: sideItems[i],
          itemColor: itemColor,
          iconSize: iconSize,
          showLabel: showLabels,
          onTap: () => onTap(globalIndex),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────
//  INDIVIDUAL NAV ITEM
// ─────────────────────────────────────────────
class _NavItemWidget extends StatelessWidget {
  final BottomNavItem item;
  final Color itemColor;
  final double iconSize;
  final bool showLabel;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.itemColor,
    required this.iconSize,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: itemColor.withOpacity(0.1),
        highlightColor: itemColor.withOpacity(0.05),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: iconSize,
                color: itemColor,
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: itemColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NOTCH PAINTER
// ─────────────────────────────────────────────
class _NotchPainter extends CustomPainter {
  final Color color;
  final double notchRadius;
  final double gapWidth;

  _NotchPainter({
    required this.color,
    required this.notchRadius,
    required this.gapWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (notchRadius == 0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      final cx = size.width / 2;
      // 4px breathing room so FAB ring doesn't touch the bar edge
      const margin = 4.0;
      final r = notchRadius + margin;
      // Kappa: best cubic bezier constant for circle quarter approximation
      const k = 0.5523;
      const corner = 20.0;

      path.moveTo(0, corner);
      path.quadraticBezierTo(0, 0, corner, 0);

      // Straight edge up to left notch entry
      path.lineTo(cx - r, 0);

      // ── Left quadrant of semicircle: (cx-r, 0) → (cx, r) curving DOWN ──
      path.cubicTo(
        cx - r,       r * k,   // CP1 – pull downward
        cx - r * k,   r,       // CP2 – sweep toward center
        cx,           r,       // end at semicircle bottom
      );

      // ── Right quadrant: (cx, r) → (cx+r, 0) curving UP ──
      path.cubicTo(
        cx + r * k,   r,       // CP1 – sweep outward
        cx + r,       r * k,   // CP2 – pull upward
        cx + r,       0,       // end at right notch exit
      );

      // Straight edge and bar corners
      path.lineTo(size.width - corner, 0);
      path.quadraticBezierTo(size.width, 0, size.width, corner);
      path.lineTo(size.width, size.height - 8);
      path.quadraticBezierTo(size.width, size.height, size.width - 8, size.height);
      path.lineTo(8, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - 8);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NotchPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.notchRadius != notchRadius ||
      oldDelegate.gapWidth != gapWidth;
}


