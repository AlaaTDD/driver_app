import 'dart:developer' as developer;
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../services/supabase_service.dart';
import '../bloc/ride_offer_bloc.dart';
import '../bloc/ride_offer_event.dart';
import '../bloc/ride_offer_state.dart';
import '../data/models/ride_offer_model.dart';

/// Shows a high-priority notification. Works on both Android and iOS.
Future<void> _fireRideNotification(RideOfferModel offer) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ride_offer_channel',
            'طلبات الرحلات',
            description: 'إشعارات طلبات الرحلات الجديدة',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'ride_offer_channel',
      'طلبات الرحلات',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await plugin.show(
      notificationId,
      '🚖 رحلة جديدة متاحة!',
      '${offer.pickupAddress} → ${offer.destinationAddress}\n💰 ${offer.estimatedPrice.toStringAsFixed(0)} ج.م  ·  📍 ${offer.distance.toStringAsFixed(1)} كم',
      details,
    );
    developer.log('showRideOfferOverlay: ✅ Notification shown (id=$notificationId)');
  } catch (e) {
    developer.log('showRideOfferOverlay: ❌ Notification failed: $e');
  }
}

/// Handles incoming ride-offer FCM notifications (foreground & background)
Future<void> handleRideOfferNotification(Map<String, dynamic> data) async {
  try {
    final type = data['type'] ?? data['notification_type'];
    if (type != 'ride_offer') {
      developer.log('handleRideOfferNotification: type=$type, not ride_offer, skipping');
      return;
    }

    // Extract trip_id from FCM data payload
    final tripId = data['trip_id'] as String? ?? 
                   (data['data'] is Map ? data['data']['trip_id'] as String? : null) ??
                   data['id'] as String?;

    developer.log('handleRideOfferNotification: tripId=$tripId, raw data keys=${data.keys.toList()}');

    if (tripId == null || tripId.isEmpty) {
      developer.log('handleRideOfferNotification: NO trip_id found in payload!');
      return;
    }

    final pickupAddress = data['pickup_address'] as String? ?? '';
    final destinationAddress = data['destination_address'] as String? ?? '';

    RideOfferModel offer;

    if (pickupAddress.isNotEmpty || destinationAddress.isNotEmpty) {
      // We have enriched data from the Edge Function — use it directly
      developer.log('handleRideOfferNotification: Using enriched FCM payload (no DB query needed)');
      offer = RideOfferModel(
        id: tripId,
        passengerName: data['passenger_name'] as String? ?? '',
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        distance: double.tryParse(data['distance_km']?.toString() ?? '') ?? 0.0,
        estimatedPrice: double.tryParse(data['price']?.toString() ?? '') ?? 0.0,
        vehicleType: data['vehicle_type'] as String? ?? 'car',
        pickupLat: double.tryParse(data['pickup_lat']?.toString() ?? ''),
        pickupLng: double.tryParse(data['pickup_lng']?.toString() ?? ''),
        destinationLat: double.tryParse(data['destination_lat']?.toString() ?? ''),
        destinationLng: double.tryParse(data['destination_lng']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
    } else {
      // Fallback: fetch from Supabase (only works if auth session is available)
      developer.log('handleRideOfferNotification: No enriched data, falling back to Supabase query...');
      try {
        final tripRow = await SupabaseService.client
            .from('trips')
            .select('*, user:users!trips_user_id_fkey(name, phone)')
            .eq('id', tripId)
            .maybeSingle();

        if (tripRow == null) {
          developer.log('handleRideOfferNotification: Trip $tripId not found in DB!');
          return;
        }

        developer.log('handleRideOfferNotification: Trip fetched from DB: ${tripRow['pickup_address']}');
        final passengerName = tripRow['user']?['name'] as String? ?? '';
        offer = RideOfferModel(
          id: tripId,
          passengerName: passengerName,
          pickupAddress: tripRow['pickup_address'] as String? ?? '',
          destinationAddress: tripRow['destination_address'] as String? ?? '',
          distance: (tripRow['distance_km'] as num?)?.toDouble() ?? 0.0,
          estimatedPrice: (tripRow['price'] as num?)?.toDouble() ?? 0.0,
          vehicleType: tripRow['vehicle_type'] as String? ?? 'car',
          pickupLat: (tripRow['pickup_lat'] as num?)?.toDouble(),
          pickupLng: (tripRow['pickup_lng'] as num?)?.toDouble(),
          destinationLat: (tripRow['destination_lat'] as num?)?.toDouble(),
          destinationLng: (tripRow['destination_lng'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(tripRow['created_at'] as String? ?? '') ?? DateTime.now(),
        );
      } catch (dbError) {
        developer.log('handleRideOfferNotification: Supabase fallback failed: $dbError');
        offer = RideOfferModel(
          id: tripId,
          passengerName: '',
          pickupAddress: data['title'] as String? ?? 'طلب رحلة جديد',
          destinationAddress: data['body'] as String? ?? '',
          distance: 0.0,
          estimatedPrice: 0.0,
          vehicleType: 'car',
          createdAt: DateTime.now(),
        );
      }
    }

    developer.log('handleRideOfferNotification: RideOfferModel built — id=${offer.id}, pickup=${offer.pickupAddress}, price=${offer.estimatedPrice}');

    // Fire the high priority local notification
    await _fireRideNotification(offer);
  } catch (e, st) {
    developer.log(
      'handleRideOfferNotification error',
      error: e,
      stackTrace: st,
    );
  }
}

// ============================================================
// In-App Overlay (when app is in foreground — uses BLoC)
// ============================================================
class RideOfferInAppOverlay extends StatelessWidget {
  final Widget child;

  const RideOfferInAppOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideOfferBloc, RideOfferState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.remainingSeconds != current.remainingSeconds,
      listener: (context, state) {
        if (state.status == RideOfferStatus.incoming &&
            state.currentOffer != null) {
          _showInAppDialog(context, state);
        }
      },
      child: child,
    );
  }

  void _showInAppDialog(BuildContext context, RideOfferState state) {
    final offer = state.currentOffer!;
    final bloc = context.read<RideOfferBloc>();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(180),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _RideOfferDialog(
          offer: offer,
          remainingSeconds: state.remainingSeconds,
        ),
      ),
    );
  }
}

class _RideOfferDialog extends StatefulWidget {
  final RideOfferModel offer;
  final int remainingSeconds;

  const _RideOfferDialog({
    required this.offer,
    required this.remainingSeconds,
  });

  @override
  State<_RideOfferDialog> createState() => _RideOfferDialogState();
}

class _RideOfferDialogState extends State<_RideOfferDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.newRideRequest,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            BlocBuilder<RideOfferBloc, RideOfferState>(
              buildWhen: (p, c) => p.remainingSeconds != c.remainingSeconds,
              builder: (context, state) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '0:${state.remainingSeconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  widget.offer.passengerName,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AddressRow(
              icon: Icons.location_on,
              label: AppLocalizations.of(context)!.fromLabel,
              address: widget.offer.pickupAddress,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 8),
            _AddressRow(
              icon: Icons.flag,
              label: AppLocalizations.of(context)!.toLabel,
              address: widget.offer.destinationAddress,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoChip(
                  icon: Icons.attach_money,
                  value: AppLocalizations.of(context)!.priceWithCurrency(
                      widget.offer.estimatedPrice.toStringAsFixed(0),
                      AppLocalizations.of(context)!.egp),
                  color: const Color(0xFF00E676),
                ),
                _InfoChip(
                  icon: Icons.route,
                  value: AppLocalizations.of(context)!.distanceWithKm(
                      widget.offer.distance.toStringAsFixed(1)),
                  color: Colors.blueAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context
                          .read<RideOfferBloc>()
                          .add(RideOfferDeclined(widget.offer.id));
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.rejectBtn, style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context
                          .read<RideOfferBloc>()
                          .add(RideOfferAccepted(widget.offer.id));
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.acceptBtn,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;

  const _AddressRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $address',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
