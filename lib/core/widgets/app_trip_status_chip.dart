import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/utils/trip_status.dart';
import 'package:snapix/core/widgets/app_badge.dart';

class AppTripStatusChip extends StatelessWidget {
  final TripStatus status;
  final String Function(TripStatus) labelBuilder;

  const AppTripStatusChip({
    super.key,
    required this.status,
    required this.labelBuilder,
  });

  AppBadgeVariant get _variant => switch (status) {
        TripStatus.searching => AppBadgeVariant.primary,
        TripStatus.accepted => AppBadgeVariant.info,
        TripStatus.inProgress => AppBadgeVariant.success,
        TripStatus.completed => AppBadgeVariant.neutral,
        TripStatus.cancelled => AppBadgeVariant.error,
      };

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: labelBuilder(status),
      variant: _variant,
      dot: status == TripStatus.inProgress || status == TripStatus.searching,
    );
  }
}
