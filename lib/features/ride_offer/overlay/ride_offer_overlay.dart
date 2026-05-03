
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:system_alert_window/system_alert_window.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../services/supabase_service.dart';
import '../bloc/ride_offer_bloc.dart';
import '../bloc/ride_offer_event.dart';
import '../bloc/ride_offer_state.dart';
import '../data/models/ride_offer_model.dart';

// ──────────────────────────────────────────────
// Port names for IsolateNameServer communication
// ──────────────────────────────────────────────
const String _mainAppPort = 'RideOfferMainApp';
const String _overlayPort = 'RideOfferOverlay';

SendPort? _mainAppSendPort;

// ──────────────────────────────────────────────
// Main App Port — receives messages from the overlay
// ──────────────────────────────────────────────
void registerMainAppPort() {
  // Remove stale registration first
  IsolateNameServer.removePortNameMapping(_mainAppPort);

  final port = ReceivePort();
  if (IsolateNameServer.registerPortWithName(port.sendPort, _mainAppPort)) {
    port.listen((message) {
      developer.log('MainApp received from overlay: $message');
      if (message is String) {
        try {
          final payload = jsonDecode(message) as Map<String, dynamic>;
          final action = payload['action'] as String?;
          final offerId = payload['offerId'] as String?;
          if (offerId == null || offerId.isEmpty) return;

          if (action == 'accept') {
            _handleAccept(offerId);
          } else if (action == 'decline') {
            _handleDecline(offerId);
          }
        } catch (e, st) {
          developer.log('registerMainAppPort parse error',
              error: e, stackTrace: st);
        }
      }
    });
  }
}

/// Handle ride acceptance via Supabase
Future<void> _handleAccept(String offerId) async {
  try {
    await SupabaseService.client
        .from('trip_offers')
        .update({
          'driver_id': SupabaseService.client.auth.currentUser?.id,
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', offerId);
    developer.log('Overlay accept handled for $offerId');
  } catch (e, st) {
    developer.log('Overlay accept error', error: e, stackTrace: st);
  }
}

/// Handle ride decline via Supabase
Future<void> _handleDecline(String offerId) async {
  try {
    await SupabaseService.client
        .from('trip_offers')
        .update({'status': 'declined'})
        .eq('id', offerId);
    developer.log('Overlay decline handled for $offerId');
  } catch (e, st) {
    developer.log('Overlay decline error', error: e, stackTrace: st);
  }
}

// ============================================================
// OVERLAY ENTRY POINT
// Called by Android when the system overlay window starts.
// Runs in a separate Flutter Engine — no access to BLoC/Provider
// ============================================================
@pragma('vm:entry-point')
void rideOfferOverlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  final overlayReceivePort = ReceivePort();
  _mainAppSendPort = IsolateNameServer.lookupPortByName(_mainAppPort);

  // Register overlay port so the background handler can push data
  IsolateNameServer.removePortNameMapping(_overlayPort);
  IsolateNameServer.registerPortWithName(
    overlayReceivePort.sendPort,
    _overlayPort,
  );

  overlayReceivePort.listen((dynamic data) {
    developer.log('Overlay received: $data');
    SystemAlertWindow.sendMessageToOverlay(data);
  });

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: null, // Use system font — custom fonts may not load in overlay
      ),
      home: const _RideOfferOverlayWidget(),
    ),
  );
}

// ============================================================
// Overlay Widget (self-contained, no BLoC access)
// ============================================================
class _RideOfferOverlayWidget extends StatefulWidget {
  const _RideOfferOverlayWidget();

  @override
  State<_RideOfferOverlayWidget> createState() =>
      _RideOfferOverlayWidgetState();
}

class _RideOfferOverlayWidgetState extends State<_RideOfferOverlayWidget> {
  RideOfferModel? _offer;
  int _remainingSeconds = 30;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    SystemAlertWindow.overlayListener.listen((dynamic event) {
      developer.log('Overlay listener event: $event');
      if (event is String) {
        try {
          final map = jsonDecode(event) as Map<String, dynamic>;
          final offer = RideOfferModel.fromJson(map);
          setState(() {
            _offer = offer;
            _remainingSeconds = 30;
            _isProcessing = false;
          });
          _startCountdown();
        } catch (e) {
          developer.log('Overlay parse error: $e');
        }
      }
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds > 0) {
          _startCountdown();
        } else {
          _sendAction('decline'); // Auto-decline on timeout
        }
      }
    });
  }

  // ──────────────────────────────────────────────
  // Send action to Main App (or directly to Supabase if app is closed)
  // ──────────────────────────────────────────────
  void _sendAction(String action) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _mainAppSendPort ??= IsolateNameServer.lookupPortByName(_mainAppPort);

    if (_mainAppSendPort != null) {
      // App is running → send via IsolateNameServer
      _mainAppSendPort?.send(jsonEncode({
        'action': action,
        'offerId': _offer?.id,
      }));
    } else {
      // App is terminated → send directly to Supabase via HTTP
      await _sendDirectToSupabase(
        action == 'accept' ? 'accepted' : 'declined',
        _offer?.id ?? '',
      );
    }

    await SystemAlertWindow.closeSystemWindow(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
  }

  /// Fallback: send ride response directly to Supabase when app is closed
  Future<void> _sendDirectToSupabase(String status, String offerId) async {
    if (offerId.isEmpty) return;
    try {
      // Use environment variables stored in the overlay context
      // NOTE: These values must match your .env configuration
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      // If build-time env vars are not available, log and return
      if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
        developer.log(
          'Overlay direct Supabase: env vars not available, skipping',
        );
        return;
      }

      final body = status == 'accepted'
          ? jsonEncode({
              'status': status,
              'accepted_at': DateTime.now().toIso8601String(),
            })
          : jsonEncode({'status': status});

      final response = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/trip_offers?id=eq.$offerId'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Prefer': 'return=minimal',
        },
        body: body,
      );
      developer.log('Supabase direct response: ${response.statusCode}');
    } catch (e) {
      developer.log('Error sending directly to Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_offer == null) {
      return const SizedBox.shrink();
    }

    final offer = _offer!;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header ───
              _buildHeader(offer),
              const Divider(color: Colors.white24, height: 1),

              // ─── Ride Details ───
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAddressRow(
                      icon: Icons.radio_button_checked,
                      iconColor: Colors.green,
                      label: 'نقطة الانطلاق',
                      value: offer.pickupAddress.isEmpty
                          ? 'جارٍ التحميل...'
                          : offer.pickupAddress,
                    ),
                    const SizedBox(height: 8),
                    _buildAddressRow(
                      icon: Icons.location_on,
                      iconColor: Colors.red,
                      label: 'الوجهة',
                      value: offer.destinationAddress.isEmpty
                          ? 'جارٍ التحميل...'
                          : offer.destinationAddress,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip(
                          '💰 ${offer.estimatedPrice.toStringAsFixed(0)} ج.م',
                          Colors.amber,
                        ),
                        _buildInfoChip(
                          '📍 ${offer.distance.toStringAsFixed(1)} كم',
                          Colors.blue,
                        ),
                        _buildInfoChip(
                          '⏱ ${_remainingSeconds}ث',
                          _remainingSeconds <= 10
                              ? Colors.red
                              : Colors.white54,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── Action Buttons ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    // Reject button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _sendAction('decline'),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text(
                          'رفض',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _sendAction('accept'),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'قبول',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43A047),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ───

  Widget _buildHeader(RideOfferModel offer) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_taxi, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طلب رحلة جديدة! 🚖',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (offer.passengerName.isNotEmpty)
                  Text(
                    'الراكب: ${offer.passengerName}',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
              ],
            ),
          ),
          // Countdown Circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _remainingSeconds <= 10 ? Colors.red : Colors.white24,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$_remainingSeconds',
                style: TextStyle(
                  color: _remainingSeconds <= 10 ? Colors.red : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================
// Show the system overlay window from FCM handler
// ============================================================

Future<void> showRideOfferOverlay(RideOfferModel offer) async {
  bool hasPermission = false;
  try {
    final result = await SystemAlertWindow.checkPermissions(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
    hasPermission = result ?? false;
  } catch (e) {
    developer.log('RideOfferOverlay check permissions failed: $e');
  }

  if (hasPermission) {
    try {
      // Send ride data to the overlay before opening it
      final overlayPort = IsolateNameServer.lookupPortByName(_overlayPort);
      if (overlayPort != null) {
        overlayPort.send(jsonEncode(offer.toJson()));
      }

      await SystemAlertWindow.sendMessageToOverlay(
        jsonEncode(offer.toJson()),
      );

      // Open the overlay window
      await SystemAlertWindow.showSystemWindow(
        gravity: SystemWindowGravity.TOP,
        width: -1, // MATCH_PARENT
        height: 340,
        notificationTitle: '🚖 رحلة جديدة!',
        notificationBody: '${offer.pickupAddress} → ${offer.destinationAddress}',
        prefMode: SystemWindowPrefMode.OVERLAY,
      );
      return; // Successfully showed overlay
    } catch (e) {
      developer.log('RideOfferOverlay failed to show window: $e');
    }
  }

  // Fallback for Android 9+ background limits if overlay fails
  // Wakes up screen and shows high-priority notification with fullScreenIntent
  developer.log('RideOfferOverlay: Using Full-Screen Intent Fallback');
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.max,
    icon: '@mipmap/ic_launcher',
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
  );
  const details = NotificationDetails(android: androidDetails);
  
  await flutterLocalNotificationsPlugin.show(
    offer.id.hashCode,
    '🚖 رحلة جديدة متاحة!',
    '${offer.pickupAddress} → ${offer.destinationAddress}\nالمسافة: ${offer.distance} كم | السعر: ${offer.estimatedPrice} ج.م',
    details,
  );
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
              'طلب رحلة جديد',
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
              label: 'من',
              address: widget.offer.pickupAddress,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 8),
            _AddressRow(
              icon: Icons.flag,
              label: 'إلى',
              address: widget.offer.destinationAddress,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoChip(
                  icon: Icons.attach_money,
                  value:
                      '${widget.offer.estimatedPrice.toStringAsFixed(0)} ج.م',
                  color: const Color(0xFF00E676),
                ),
                _InfoChip(
                  icon: Icons.route,
                  value:
                      '${widget.offer.distance.toStringAsFixed(1)} كم',
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
                    child: const Text('رفض', style: TextStyle(fontSize: 16)),
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
                    child: const Text(
                      'قبول',
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
