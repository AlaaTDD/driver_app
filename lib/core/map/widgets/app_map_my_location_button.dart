import 'package:flutter/material.dart';
import 'package:snapix/core/widgets/map_button.dart';
import 'package:snapix/core/map/constants/app_map_constants.dart';

/// Reusable "my location" floating button positioned at the bottom-right of the
/// map stack. Wraps [MapButton] with consistent positioning.
class AppMapMyLocationButton extends StatelessWidget {
  final VoidCallback onTap;
  final double bottomOffset;
  final double rightOffset;

  const AppMapMyLocationButton({
    super.key,
    required this.onTap,
    this.bottomOffset = AppMapConstants.locationButtonBottomDefault,
    this.rightOffset = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottomOffset,
      right: rightOffset,
      child: MapButton(
        icon: Icons.my_location_rounded,
        onTap: onTap,
      ),
    );
  }
}
