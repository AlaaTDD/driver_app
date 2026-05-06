
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
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
    // Need to import localizations at top, but we can do it via AppLocalizations
    final l = AppLocalizations.of(context)!;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.local_taxi_outlined : Icons.route_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.noTrips,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? l.noActiveTrips : l.tripsWillAppearHere,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 24),
            _GradientButton(
              onPressed: () => Navigator.pop(context),
              icon: Icons.local_taxi,
              label: l.backToHome,
            ),
          ],
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
