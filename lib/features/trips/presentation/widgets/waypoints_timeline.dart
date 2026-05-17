import 'package:flutter/material.dart';
import '../../../../core/models/trip_route_waypoint_model.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// A vertical timeline widget that displays multi-route waypoints (stopovers)
/// between the pickup and destination points.
///
/// Visually represents each waypoint as a dot on a vertical line,
/// with role-based coloring (origin = green, stopover = amber, destination = blue).
class WaypointsTimeline extends StatelessWidget {
  final List<TripRouteWaypointModel> waypoints;
  final VoidCallback? onAddStopover;
  final void Function(String waypointId)? onRemoveStopover;
  final void Function(String waypointId)? onMarkArrived;
  final void Function(String waypointId)? onMarkDeparted;
  final bool isEditable;
  final bool isDriver;

  const WaypointsTimeline({
    super.key,
    required this.waypoints,
    this.onAddStopover,
    this.onRemoveStopover,
    this.onMarkArrived,
    this.onMarkDeparted,
    this.isEditable = false,
    this.isDriver = false,
  });

  @override
  Widget build(BuildContext context) {
    if (waypoints.isEmpty) return const SizedBox.shrink();

    final sorted = List<TripRouteWaypointModel>.from(waypoints)
      ..sort((a, b) => a.seqOrder.compareTo(b.seqOrder));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...sorted.asMap().entries.map((entry) {
          final index = entry.key;
          final wp = entry.value;
          final isLast = index == sorted.length - 1;
          return _WaypointRow(
            waypoint: wp,
            isLast: isLast,
            isEditable: isEditable && wp.isStopover,
            isDriver: isDriver,
            onRemove: onRemoveStopover != null && wp.isStopover
                ? () => onRemoveStopover!(wp.id)
                : null,
            onMarkArrived: onMarkArrived != null && !wp.hasArrived
                ? () => onMarkArrived!(wp.id)
                : null,
            onMarkDeparted:
                onMarkDeparted != null && wp.hasArrived && !wp.hasDeparted
                    ? () => onMarkDeparted!(wp.id)
                    : null,
          );
        }),
        // Add stopover button
        if (isEditable && onAddStopover != null) ...[
          const SizedBox(height: 8),
          _AddStopoverButton(onTap: onAddStopover!),
        ],
      ],
    );
  }
}

// ─── Single Waypoint Row ──────────────────────────────────────────────────────

class _WaypointRow extends StatelessWidget {
  final TripRouteWaypointModel waypoint;
  final bool isLast;
  final bool isEditable;
  final bool isDriver;
  final VoidCallback? onRemove;
  final VoidCallback? onMarkArrived;
  final VoidCallback? onMarkDeparted;

  const _WaypointRow({
    required this.waypoint,
    required this.isLast,
    this.isEditable = false,
    this.isDriver = false,
    this.onRemove,
    this.onMarkArrived,
    this.onMarkDeparted,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = _roleColor(waypoint.role);
    final icon = _roleIcon(waypoint.role);
    final label = _roleLabel(context, waypoint.role);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline column (dot + line) ──
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.5),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Content column ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Role label + status badges
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0,
                        ),
                      ),
                      if (waypoint.hasArrived) ...[
                        const SizedBox(width: 6),
                        _StatusChip(
                          label: l.arrivalConfirmed,
                          color: AppColors.success,
                        ),
                      ],
                      if (waypoint.hasDeparted) ...[
                        const SizedBox(width: 4),
                        _StatusChip(
                          label: l.departureConfirmed,
                          color: AppColors.primary,
                        ),
                      ],
                      if (isDriver &&
                          !waypoint.hasArrived &&
                          onMarkArrived != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onMarkArrived,
                          child: _StatusChip(
                            label: l.confirmArrival,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                      if (isDriver &&
                          waypoint.hasArrived &&
                          !waypoint.hasDeparted &&
                          onMarkDeparted != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onMarkDeparted,
                          child: _StatusChip(
                            label: l.confirmDeparture,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isEditable && onRemove != null)
                        GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Address
                  Text(
                    waypoint.address ??
                        '${waypoint.lat.toStringAsFixed(4)}, ${waypoint.lng.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textPrimary
                          : AppColors.surface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Distance / duration metadata
                  if (waypoint.legDistanceKm != null ||
                      waypoint.legDurationMin != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (waypoint.legDistanceKm != null)
                            _MetaChip(
                              icon: Icons.straighten_rounded,
                              text:
                                  '${waypoint.legDistanceKm!.toStringAsFixed(1)} كم',
                            ),
                          if (waypoint.legDistanceKm != null &&
                              waypoint.legDurationMin != null)
                            const SizedBox(width: 8),
                          if (waypoint.legDurationMin != null)
                            _MetaChip(
                              icon: Icons.schedule_rounded,
                              text:
                                  '${waypoint.legDurationMin!.toStringAsFixed(0)} د',
                            ),
                        ],
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

  Color _roleColor(RouteWaypointRole role) => switch (role) {
        RouteWaypointRole.origin => AppColors.success,
        RouteWaypointRole.stopover => AppColors.warning,
        RouteWaypointRole.destination => AppColors.primary,
      };

  IconData _roleIcon(RouteWaypointRole role) => switch (role) {
        RouteWaypointRole.origin => Icons.trip_origin_rounded,
        RouteWaypointRole.stopover => Icons.location_on_rounded,
        RouteWaypointRole.destination => Icons.flag_rounded,
      };

  String _roleLabel(BuildContext context, RouteWaypointRole role) {
    final l = AppLocalizations.of(context)!;
    return switch (role) {
      RouteWaypointRole.origin => l.pickupPoint,
      RouteWaypointRole.stopover => l.stopover,
      RouteWaypointRole.destination => l.destination,
    };
  }
}

// ─── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
}

// ─── Meta Chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
}

// ─── Add Stopover Button ──────────────────────────────────────────────────────

class _AddStopoverButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddStopoverButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.2),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_location_alt_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.addStopover,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      );
}
