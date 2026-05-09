
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import 'animated_trip_card.dart';

class TripListView extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final bool isActive;

  const TripListView({
    super.key,
    required this.trips,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return EmptyState(isActive: isActive);
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final trip in trips) {
      final date = _formatDate(trip['created_at']);
      grouped.putIfAbsent(date, () => []).add(trip);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return TripDateSection(
          dateLabel: entry.key,
          trips: entry.value,
          isActive: isActive,
        );
      },
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateValue.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }
}

class TripDateSection extends StatelessWidget {
  final String dateLabel;
  final List<Map<String, dynamic>> trips;
  final bool isActive;

  const TripDateSection({
    super.key,
    required this.dateLabel,
    required this.trips,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    const t2 = Color(0xFF7B82A3);
    const blue = Color(0xFF4C8BF5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(
              color: blue, borderRadius: BorderRadius.circular(2)
            )),
            const SizedBox(width: 8),
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t2,
                letterSpacing: 0.5,
              ),
            ),
          ]),
        ),
        ...trips.asMap().entries.map((entry) {
          return AnimatedTripCard(
            trip: entry.value,
            isActive: isActive,
            delay: entry.key * 50,
          );
        }),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final bool isActive;
  const EmptyState({super.key, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const blue = Color(0xFF4C8BF5);
    const t1   = Color(0xFFEEF0FF);
    const t2   = Color(0xFF7B82A3);
    
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
            style: const TextStyle(color: t1, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? l.noActiveTrips : l.tripsWillAppearHere,
            style: const TextStyle(color: t2, fontSize: 14),
          ),
          if (isActive) ...[
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blue, Color(0xFF1F5EC4)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(l.backToHome,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
