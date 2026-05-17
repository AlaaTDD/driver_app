import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../services/supabase_service.dart';

class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  List<Map<String, dynamic>> _revisions = [];
  bool _loadingRevisions = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _subscribeRevisions();
  }

  void _subscribeRevisions() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      setState(() => _loadingRevisions = false);
      return;
    }

    _sub = SupabaseService.client
        .from('driver_revision_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', uid)
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _revisions = rows;
              _loadingRevisions = false;
            });
          },
          onError: (e, st) {
            debugPrint(
                '❌ PendingVerificationScreen: revision stream failed: $e\n$st');
            if (mounted) setState(() => _loadingRevisions = false);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // ── Status icon ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_outlined,
                  size: 64,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.accountUnderReview,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l.reviewDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),

              // ── Revision requests section ───────────────────────────────
              if (_loadingRevisions) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ] else if (_revisions.isNotEmpty) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_note_rounded,
                            color: AppColors.error, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${l.driverRevisionRequests} (${_revisions.length})',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _revisions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _RevisionCard(revision: _revisions[i]),
                  ),
                ),
              ],

              const Spacer(),
              // ── Logout button ───────────────────────────────────────────
              AppButton(
                text: l.logout,
                onPressed: () {
                  context.read<AuthBloc>().add(SignOutRequested());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single revision card ──────────────────────────────────────────────────────

class _RevisionCard extends StatelessWidget {
  final Map<String, dynamic> revision;
  const _RevisionCard({required this.revision});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fields = _fields(context);
    final message = revision['message'] as String? ?? '';
    final status = revision['status'] as String? ?? 'pending';
    final isResolved = status == 'resolved';

    final statusColor = isResolved ? AppColors.success : AppColors.error;
    final statusLabel = isResolved ? l.completed : l.revisionNeedsAction;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.fieldsRequested,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fields
                .map(
                  (field) => Chip(
                    label: Text(field),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: context.elevatedColor,
                    side: BorderSide(color: context.divColor),
                  ),
                )
                .toList(),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _fields(BuildContext context) {
    final raw = revision['fields_requested'];
    final values = raw is List
        ? raw.map((field) => field.toString()).toList()
        : <String>[];
    if (values.isEmpty && revision['field_name'] != null) {
      values.add(revision['field_name'].toString());
    }
    if (values.isEmpty) return [AppLocalizations.of(context)!.unspecified];
    return values.map((field) => _fieldLabel(context, field)).toList();
  }

  String _fieldLabel(BuildContext context, String field) {
    final l = AppLocalizations.of(context)!;
    return switch (field) {
      'national_id' || 'national_id_image_url' => l.nationalId,
      'license_number' || 'license_image_url' => l.driverLicense,
      'criminal_record_url' => l.criminalRecord,
      'vehicle_type' => l.vehicleType,
      'vehicle_brand' => l.vehicleBrand,
      'vehicle_model' => l.vehicleModel,
      'vehicle_year' => l.vehicleYear,
      'vehicle_color' => l.vehicleColor,
      'vehicle_plate' => l.plateNumber,
      'vehicle_image_url' => l.vehiclePhoto,
      _ => field,
    };
  }
}
