import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/supabase_service.dart';
import '../../../../core/constants/app_routes.dart';

// ─── Design tokens (match driver palette) ────────────────────────────────────
class _C {
  static const bg       = Color(0xFF0D0F18);
  static const sheet    = Color(0xFF12151F);
  static const card     = Color(0xFF181C2A);
  static const elevated = Color(0xFF1E2336);
  static const border   = Color(0xFF252A3D);
  static const blue     = Color(0xFF4C8BF5);
  static const emerald  = Color(0xFF1FC87A);
  static const rose     = Color(0xFFFF4060);
  static const amber    = Color(0xFFF5A524);
  static const t1       = Color(0xFFEEF0FF);
  static const t2       = Color(0xFF7B82A3);
  static const t3       = Color(0xFF3A4060);
}

class DriverRequestFeedScreen extends StatefulWidget {
  const DriverRequestFeedScreen({super.key});

  @override
  State<DriverRequestFeedScreen> createState() => _DriverRequestFeedScreenState();
}

class _DriverRequestFeedScreenState extends State<DriverRequestFeedScreen> {
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) return;

    _sub = SupabaseService.client
        .from('trip_offers')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .listen((rows) {
      if (!mounted) return;
      // Only show pending offers; realtime removes the card when status changes
      final pending = rows
          .where((r) => r['status'] == 'pending')
          .toList()
        ..sort((a, b) => DateTime.parse(a['created_at'] as String)
            .compareTo(DateTime.parse(b['created_at'] as String)));
      setState(() {
        _offers = pending;
        _loading = false;
      });
    }, onError: (_) => setState(() => _loading = false));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _accept(String offerId, String tripId) async {
    try {
      final result = await SupabaseService.client
          .rpc('driver_accept_trip', params: {'p_trip_id': tripId});
      if (result != null && result['success'] == true && mounted) {
        context.push('${AppRoutes.driverTripDetails}?tripId=$tripId');
      }
    } catch (e) {
      debugPrint('RequestFeed: accept failed — $e');
    }
  }

  Future<void> _reject(String offerId) async {
    try {
      await SupabaseService.client
          .from('trip_offers')
          .update({'status': 'declined'})
          .eq('id', offerId);
      // Realtime stream will remove the card automatically
    } catch (e) {
      debugPrint('RequestFeed: reject failed — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _C.sheet,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.t1, size: 17),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('طلبات الرحلات', style: TextStyle(
                        color: _C.t1, fontSize: 18, fontWeight: FontWeight.w800)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _loading ? 'جاري التحميل...'
                            : _offers.isEmpty ? 'لا توجد طلبات متاحة حالياً'
                            : '${_offers.length} طلب متاح',
                        key: ValueKey(_offers.length),
                        style: const TextStyle(color: _C.t2, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
                // Live indicator dot
                if (!_loading)
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _offers.isEmpty ? _C.t3 : _C.emerald,
                      shape: BoxShape.circle,
                      boxShadow: _offers.isEmpty ? null : [
                        BoxShadow(color: _C.emerald.withValues(alpha: 0.5), blurRadius: 8),
                      ],
                    ),
                  ),
              ]),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator(color: _C.blue, strokeWidth: 2))
                : _offers.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _offers.length,
                        itemBuilder: (_, i) => _OfferCard(
                          key: ValueKey(_offers[i]['id']),
                          offer: _offers[i],
                          onAccept: _accept,
                          onReject: _reject,
                        ),
                      )),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            color: _C.elevated,
            shape: BoxShape.circle,
            border: Border.all(color: _C.border),
          ),
          child: const Icon(Icons.inbox_rounded, color: _C.t3, size: 40),
        ),
        const SizedBox(height: 20),
        const Text('لا توجد طلبات متاحة', style: TextStyle(
            color: _C.t1, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('ستظهر هنا طلبات الرحلات عند ورودها',
            style: TextStyle(color: _C.t2, fontSize: 13)),
      ]),
    );
  }
}

// ─── Single offer card with countdown timer ───────────────────────────────────
class _OfferCard extends StatefulWidget {
  final Map<String, dynamic> offer;
  final Future<void> Function(String offerId, String tripId) onAccept;
  final Future<void> Function(String offerId) onReject;

  const _OfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  Timer? _timer;
  int _seconds = 30;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    // Compute remaining seconds from created_at + 30s window
    final createdAt = DateTime.tryParse(widget.offer['created_at'] as String? ?? '');
    if (createdAt != null) {
      final elapsed = DateTime.now().difference(createdAt).inSeconds;
      _seconds = (30 - elapsed).clamp(0, 30);
    }

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 1) {
        _timer?.cancel();
        // Auto-expire: reject silently
        widget.onReject(widget.offer['id'] as String);
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offerId  = widget.offer['id'] as String? ?? '';
    final tripId   = widget.offer['trip_id'] as String? ?? '';
    final pickup   = widget.offer['pickup_address'] as String? ?? '---';
    final dest     = widget.offer['destination_address'] as String? ?? '---';
    final price    = widget.offer['proposed_price'];
    final distance = (widget.offer['distance_km'] as num?)?.toStringAsFixed(1);
    final timerFraction = _seconds / 30.0;
    final timerColor = _seconds > 15 ? _C.emerald : _seconds > 8 ? _C.amber : _C.rose;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.border),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Timer bar ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: 4,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: timerFraction,
                child: Container(color: timerColor),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── Route info ───────────────────────────────────────────────
              Row(children: [
                Column(children: [
                  Container(width: 10, height: 10,
                      decoration: const BoxDecoration(color: _C.emerald, shape: BoxShape.circle)),
                  Container(width: 1, height: 28, color: _C.border),
                  Container(width: 10, height: 10,
                      decoration: const BoxDecoration(color: _C.rose, shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pickup, style: const TextStyle(color: _C.t1, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 14),
                    Text(dest, style: const TextStyle(color: _C.t1, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Timer circle
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: timerColor.withValues(alpha: 0.5), width: 2),
                    color: timerColor.withValues(alpha: 0.08),
                  ),
                  child: Center(child: Text('$_seconds',
                      style: TextStyle(color: timerColor, fontSize: 16, fontWeight: FontWeight.w800))),
                ),
              ]),

              const SizedBox(height: 14),

              // ── Stats row ───────────────────────────────────────────────
              Row(children: [
                if (price != null) _StatChip(
                  icon: Icons.attach_money_rounded,
                  label: '$price ج.م',
                  color: _C.amber,
                ),
                if (distance != null) ...[
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.straighten_rounded,
                    label: '$distance كم',
                    color: _C.blue,
                  ),
                ],
              ]),

              const SizedBox(height: 14),

              // ── Action buttons ──────────────────────────────────────────
              Row(children: [
                // Reject
                Expanded(
                  child: GestureDetector(
                    onTap: _acting ? null : () async {
                      setState(() => _acting = true);
                      _timer?.cancel();
                      await widget.onReject(offerId);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _C.rose.withValues(alpha: 0.5)),
                        color: _C.rose.withValues(alpha: 0.06),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.close_rounded, color: _C.rose, size: 18),
                        SizedBox(width: 6),
                        Text('رفض', style: TextStyle(color: _C.rose, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Accept
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _acting || tripId.isEmpty ? null : () async {
                      setState(() => _acting = true);
                      _timer?.cancel();
                      await widget.onAccept(offerId, tripId);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: _acting ? null : const LinearGradient(
                          colors: [_C.emerald, Color(0xFF16A05E)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        color: _acting ? _C.elevated : null,
                        boxShadow: _acting ? null : [
                          BoxShadow(color: _C.emerald.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: _acting
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('قبول الرحلة', style: TextStyle(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}
