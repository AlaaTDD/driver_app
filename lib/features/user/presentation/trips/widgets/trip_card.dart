// lib/features/user/presentation/trips/widgets/trip_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/constants/app_routes.dart';
import '../../../../../core/localization/generated/app_localizations.dart';

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isActive;

  const TripCard({super.key, required this.trip, this.isActive = false});

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('❌ Error: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = trip['status'] as String?;
    final distance = (trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0';
    final price = (trip['price'] as num?)?.toStringAsFixed(2) ?? '0.00';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('${AppRoutes.userTripDetails}?tripId=${trip['id']}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(status: status, l: l),
                      const Spacer(),
                      Icon(Icons.access_time, size: 14, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(trip['created_at'] as String?),
                        style: TextStyle(color: context.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${trip['origin_address'] ?? 'Unknown'} → ${trip['destination_address'] ?? 'Unknown'}',
                    style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('$distance km', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('$price SAR', style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  final AppLocalizations l;

  const _StatusBadge({required this.status, required this.l});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (status) {
      'completed' => (AppColors.success, l.completed),
      'cancelled' => (Colors.red, l.cancelled),
      'in_progress' => (Colors.orange, l.inProgress),
      'accepted' => (AppColors.primary, 'Accepted'),
      _ => (Colors.grey, l.pending),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

