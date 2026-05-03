
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/theme_extensions.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.cardColor,
      highlightColor: context.elevatedColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const ShimmerBox(width: 50, height: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: 150,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerTripCard extends StatelessWidget {
  const ShimmerTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 100, height: 16, borderRadius: BorderRadius.circular(4)),
                ShimmerBox(width: 60, height: 16, borderRadius: BorderRadius.circular(4)),
              ],
            ),
            const SizedBox(height: 12),
            ShimmerBox(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 8),
            ShimmerBox(width: 200, height: 14, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
            ShimmerBox(width: 80, height: 20, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      ),
    );
  }
}
