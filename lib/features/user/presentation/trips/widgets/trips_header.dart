
import 'package:flutter/material.dart';
import '../../../../../core/localization/generated/app_localizations.dart';

class TripsHeader extends StatelessWidget {
  final int total;
  final int completed;
  final int cancelled;
  final VoidCallback onBack;
  final VoidCallback onNewTrip;

  const TripsHeader({
    super.key,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.onBack,
    required this.onNewTrip,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const card    = Color(0xFF181C2A);
    const elevated= Color(0xFF1E2336);
    const border  = Color(0xFF252A3D);
    const blue    = Color(0xFF4C8BF5);
    const emerald = Color(0xFF1FC87A);
    const rose    = Color(0xFFFF4060);
    const t1      = Color(0xFFEEF0FF);
    const t2      = Color(0xFF7B82A3);
    const t3      = Color(0xFF3A4060);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: blue.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(color: blue.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          const BoxShadow(color: Colors.black38, blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: back + title + new trip ───────────────────────────────
          Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: elevated, shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: t1, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.myTrips,
                style: const TextStyle(color: t1, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 2),
              Text(l.totalTripsLabel(total),
                style: const TextStyle(color: t2, fontSize: 12, height: 1.2)),
            ])),
            GestureDetector(
              onTap: onNewTrip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blue, Color(0xFF1F5EC4)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: blue.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 5),
                  Text(l.newTripLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),

          const SizedBox(height: 16),
          Container(height: 1, color: border),
          const SizedBox(height: 14),

          // ── Stats row ──────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatChip(
              icon: Icons.check_circle_rounded,
              value: completed.toString(),
              label: l.completed,
              color: emerald,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatChip(
              icon: Icons.cancel_rounded,
              value: cancelled.toString(),
              label: l.cancelled,
              color: rose,
            )),
          ]),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const elevated = Color(0xFF1E2336);
    const border   = Color(0xFF252A3D);
    const t1       = Color(0xFFEEF0FF);
    const t2       = Color(0xFF7B82A3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
            style: const TextStyle(color: t1, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2)),
          Text(label,
            style: const TextStyle(color: t2, fontSize: 11, height: 1.2)),
        ])),
      ]),
    );
  }
}
