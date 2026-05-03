
import 'package:flutter/material.dart';
import '../theme/theme_extensions.dart';



class BottomSheetContainer extends StatelessWidget {
  final Widget child;
  final double topRadius;

  const BottomSheetContainer({
    super.key,
    required this.child,
    this.topRadius = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.divColor,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
