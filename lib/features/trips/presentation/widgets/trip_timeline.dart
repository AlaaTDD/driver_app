import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/models/trip_details_model.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Horizontal four-step timeline showing trip progression.
///
/// Previously duplicated as `_HTimeline` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
class TripTimeline extends StatelessWidget {
  final TripDetailsModel trip;
  const TripTimeline({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final steps = [
      (l.tripRequest, trip.createdAt, true),
      (l.acceptTrip, trip.acceptedAt, trip.acceptedAt != null),
      (l.startTrip, trip.startedAt, trip.startedAt != null),
      (l.completeTrip, trip.completedAt, trip.completedAt != null),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.timeline.toUpperCase(),
            style: TextStyle(
                color: context.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 18),
        Row(
          children: steps.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final done = s.$3 as bool;
            final isLast = i == steps.length - 1;

            String t = '';
            final raw = s.$2;
            if (raw != null) {
              try {
                final dt = (raw is DateTime
                        ? raw
                        : DateTime.parse(raw.toString()))
                    .toLocal();
                t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              } catch (e, st) {
                AppLogger.debug(
                    '⚠️ TripTimeline: invalid timestamp "$raw": $e\n$st');
              }
            }

            return Expanded(
                child: Row(children: [
              Expanded(
                  child: Column(children: [
                // dot
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.success : context.elevatedColor,
                    border: done
                        ? null
                        : Border.all(color: context.divColor, width: 1.5),
                    boxShadow: done
                        ? [
                            BoxShadow(
                                color:
                                    AppColors.success.withValues(alpha: 0.4),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.white, size: 11)
                      : null,
                ),
                const SizedBox(height: 7),
                Text(s.$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color:
                          done ? context.textPrimary : context.textDisabled,
                      fontSize: 9.5,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    )),
                if (t.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t,
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ],
              ])),

              // connector
              if (!isLast)
                Expanded(
                    child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: done
                          ? [
                              AppColors.success.withValues(alpha: 0.45),
                              context.divColor
                            ]
                          : [context.divColor, context.divColor],
                    ),
                  ),
                )),
            ]));
          }).toList(),
        ),
      ]),
    );
  }
}
