import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/features/trips/data/models/trip_model.dart';
import 'shared_animated_trip_card.dart';

/// Displays grouped trips by date with animated cards.
///
/// Previously duplicated as:
/// - `TripListView` in user/trips/widgets/trip_list_view.dart
/// - `_TripListView` inline in driver/trips/driver_trips_screen.dart
class SharedTripListView extends StatelessWidget {
  final List<TripModel> trips;
  final bool isActive;
  final String detailsRoute;

  const SharedTripListView({
    super.key,
    required this.trips,
    required this.detailsRoute,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return SharedEmptyState(isActive: isActive);
    }

    final grouped = <String, List<TripModel>>{};
    for (final trip in trips) {
      final date = _formatDate(trip.createdAt);
      grouped.putIfAbsent(date, () => []).add(trip);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return SharedTripDateSection(
          dateLabel: entry.key,
          trips: entry.value,
          isActive: isActive,
          detailsRoute: detailsRoute,
        );
      },
    );
  }

  String _formatDate(DateTime? dateValue) {
    if (dateValue == null) return 'Unknown';
    return DateFormat('MMM dd, yyyy').format(dateValue);
  }
}

/// A section header showing a date label with a blue bar, followed by trip cards.
class SharedTripDateSection extends StatelessWidget {
  final String dateLabel;
  final List<TripModel> trips;
  final bool isActive;
  final String detailsRoute;

  const SharedTripDateSection({
    super.key,
    required this.dateLabel,
    required this.trips,
    required this.detailsRoute,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t2 = context.textSecondary;
    const blue = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Row(children: [
            Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                    color: blue, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t2,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ]),
        ),
        ...trips.asMap().entries.map((entry) {
          return SharedAnimatedTripCard(
            trip: entry.value,
            isActive: isActive,
            delay: entry.key * 50,
            detailsRoute: detailsRoute,
          );
        }),
      ],
    );
  }
}

/// Shown when the trip list is empty.
class SharedEmptyState extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onBack;

  const SharedEmptyState({
    super.key,
    this.isActive = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const blue = AppColors.primary;
    final t1 = context.textPrimary;
    final t2 = context.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: blue.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isActive ? Icons.local_taxi_rounded : Icons.route_rounded,
              size: 56,
              color: blue.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.noTrips,
            style: TextStyle(
                color: t1, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? l.noActiveTrips : l.tripsWillAppearHere,
            style: TextStyle(color: t2, fontSize: 14),
          ),
          if (isActive) ...[
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blue, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_rounded,
                      color: AppColors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(l.backToHome,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
