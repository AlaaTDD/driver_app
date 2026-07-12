import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/revision_request_model.dart';
import '../../../../core/models/field_status_model.dart';
import '../../../../core/models/revision_request_labels.dart';
import '../../../driver/data/repositories/driver_revision_repository.dart';
import 'package:snapix/core/utils/app_logger.dart';

class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState
    extends State<PendingVerificationScreen> {
  List<RevisionRequestModel> _revisions = [];
  bool _loadingRevisions = true;
  StreamSubscription? _sub;
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _subscribeRevisions();
  }

  void _subscribeRevisions() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      setState(() => _loadingRevisions = false);
      _refreshCompleter?.complete();
      _refreshCompleter = null;
      return;
    }
    _sub = watchDriverRevisionRequests(uid).listen(
      (requests) {
        if (!mounted) return;
        setState(() {
          _revisions = requests;
          _loadingRevisions = false;
        });
        _refreshCompleter?.complete();
        _refreshCompleter = null;
      },
      onError: (e, st) {
        AppLogger.debug('❌ PendingVerificationScreen: $e\n$st');
        if (mounted) setState(() => _loadingRevisions = false);
        _refreshCompleter?.complete();
        _refreshCompleter = null;
      },
    );
  }

  Future<void> _onRefresh() {
    _refreshCompleter = Completer<void>();
    _sub?.cancel();
    _subscribeRevisions();
    return _refreshCompleter!.future;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // [دورة المراجعة الثلاثية] العنوان والوصف يعتمدان على AuthState الفعلي —
    // account_status من الـ DB حصراً — وليس نصاً ثابتاً واحداً يُعرض بلا
    // تمييز بين "مطلوب تعديل منك" (AuthDriverPending) و"قيد المراجعة فعلاً
    // من الأدمن" (AuthDriverUnderReview). قبل هذا التعديل كان نص "قيد
    // المراجعة" يظهر حتى أثناء انتظار السائق نفسه، وهو تضارب دلالي من نفس
    // النوع المحذَّر منه في MASTER_PLAN.md القسم 3.1 و7 (رغم أن الزر كان
    // مخفياً بشكل صحيح أصلاً). انظر أيضاً القسم 4.4.
    final isUnderReview =
        context.watch<AuthBloc>().state is AuthDriverUnderReview;
    final title = isUnderReview ? l.accountUnderReview : l.accountRequiresAction;
    final desc  = isUnderReview ? l.reviewDesc : l.requiresActionDesc;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _onRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom -
                            96,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            // ── Status icon ──────────────────────────
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.warning
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pending_outlined,
                                  size: 64, color: AppColors.warning),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              desc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: context.textSecondary,
                                  height: 1.5),
                            ),

                            // ── Revision requests ─────────────────────
                            if (_loadingRevisions) ...[
                              const SizedBox(height: 24),
                              const CircularProgressIndicator(
                                  color: AppColors.primary, strokeWidth: 2),
                            ] else if (_revisions.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              Align(
                                alignment:
                                    AlignmentDirectional.centerStart,
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.edit_note_rounded,
                                        color: AppColors.error,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${l.driverRevisionRequests} (${_revisions.length})',
                                    style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  for (int i = 0;
                                      i < _revisions.length;
                                      i++) ...[
                                    _SmartRevisionCard(
                                        revision: _revisions[i]),
                                    if (i != _revisions.length - 1)
                                      const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                            ],
                            const Spacer(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AppButton(
                text: l.logout,
                onPressed: () =>
                    context.read<AuthBloc>().add(SignOutRequested()),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Smart Revision Card ───────────────────────────────────────────────────────

class _SmartRevisionCard extends StatelessWidget {
  final RevisionRequestModel revision;
  const _SmartRevisionCard({required this.revision});

  @override
  Widget build(BuildContext context) {
    final l          = AppLocalizations.of(context)!;
    final isResolved = revision.isResolved;
    final cardColor  = isResolved ? AppColors.success : AppColors.primary;

    // [دورة المراجعة الثلاثية] مصدر الحقيقة الوحيد لإظهار زر التعديل هو
    // account_status عبر AuthBloc — وليس أي فحص على field_statuses أو
    // driver_revision_requests.status (انظر MASTER_PLAN.md القسم 3.1 و7).
    // الزر يظهر فقط في AuthDriverPending ("Requires Action"). في
    // AuthDriverUnderReview الحساب أُرسل فعلاً وينتظر مراجعة الأدمن، وهي
    // حالة قراءة فقط — إخفاء الزر هنا هو ما يحل الخلل الأصلي في المهمة.
    final canEdit = context.watch<AuthBloc>().state is AuthDriverPending;

    // الحقول المرتبة: requires_action أولاً، ثم pending، ثم approved
    final allFields = revision.fieldStatuses.values.toList()
      ..sort((a, b) {
        int rank(FieldStatusModel f) =>
            f.requiresAction ? 0 : f.isPending ? 1 : 2;
        return rank(a).compareTo(rank(b));
      });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(children: [
            Icon(
              isResolved
                  ? Icons.check_circle_outline_rounded
                  : Icons.pending_outlined,
              color: cardColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.fieldsRequested,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isResolved ? l.completed : l.revisionNeedsAction,
                style: TextStyle(
                    color: cardColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Per-field list ──────────────────────────────────────────
          if (allFields.isNotEmpty)
            ...allFields.map((fs) => _FieldRow(field: fs, context: context, l: l))
          else
            // Fallback: قائمة الحقول القديمة بدون تفاصيل
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: revision
                  .displayFields(context)
                  .map((f) => Chip(
                        label: Text(f),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: context.elevatedColor,
                        side: BorderSide(color: context.divColor),
                      ))
                  .toList(),
            ),

          // ── Edit button ─────────────────────────────────────────────
          if (canEdit && !isResolved && revision.fieldStatuses.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  AppRoutes.driverTargetedEdit,
                  extra: revision,
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(l.editProfile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: revision.hasActionRequired
                      ? AppColors.error
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Single field row ──────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final FieldStatusModel field;
  final BuildContext context;
  final AppLocalizations l;
  const _FieldRow({required this.field, required this.context, required this.l});

  @override
  Widget build(BuildContext ctx) {
    final label = RevisionRequestModel(
      id: '',
      fieldStatuses: {field.fieldKey: field},
    ).fieldLabel(context, field.fieldKey);

    final (Color statusColor, String statusText, IconData statusIcon) =
        field.requiresAction
            ? (AppColors.error, l.fieldStatusRequiresAction,
                Icons.warning_amber_rounded)
            : field.isApproved
                ? (AppColors.success, l.fieldStatusApproved,
                    Icons.check_circle_outline_rounded)
                : (AppColors.warning, l.fieldStatusPending,
                    Icons.hourglass_empty_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Field name + badge
        Row(children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: ctx.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        // Reason (only for requires_action)
        if (field.requiresAction &&
            field.reason != null &&
            field.reason!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 20, left: 20),
            child: Text(
              '${l.reviewReason}: ${field.reason}',
              style: TextStyle(
                  color: ctx.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 2),
        Divider(color: ctx.divColor, height: 8, thickness: 0.5),
      ]),
    );
  }
}
