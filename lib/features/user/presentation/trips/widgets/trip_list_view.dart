
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      debugPrint('⚠️ TripListView: Error parsing date: $e');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            dateLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
            ),
          ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.local_taxi_outlined : Icons.route_outlined,
              size: 64,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isActive ? 'No Active Trips' : 'Your Trips Will Appear Here',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'Book a new trip to get started'
                : 'Once you complete a trip, it will show up here',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ],
      ),
    );
  }
}
