import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_empty_state.dart';
import 'bloc/driver_revision_cubit.dart';
import 'bloc/driver_revision_state.dart';
import '../../../../core/models/revision_request_model.dart';
import '../../../../core/models/revision_request_labels.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class DriverRevisionScreen extends StatelessWidget {
  const DriverRevisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DriverRevisionCubit()..subscribe(),
      child: const _DriverRevisionView(),
    );
  }
}

class _DriverRevisionView extends StatelessWidget {
  const _DriverRevisionView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // [دورة المراجعة الثلاثية] مصدر الحقيقة الوحيد لإظهار زر التعديل هو
    // account_status عبر AuthBloc — وليس driver_revision_requests.status
    // (isResolved/resolved). نفس القاعدة المطبَّقة في
    // pending_verification_screen.dart. انظر MASTER_PLAN.md القسم 3.1 و7.
    final canEdit = context.watch<AuthBloc>().state is AuthDriverPending;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(l.driverRevisionRequests),
        backgroundColor: context.bgColor,
      ),
      body: SafeArea(
        child: BlocBuilder<DriverRevisionCubit, DriverRevisionState>(
          builder: (context, state) {
            return switch (state) {
              DriverRevisionInitial() ||
              DriverRevisionLoading() =>
                const Center(child: CircularProgressIndicator()),
              DriverRevisionError(:final errorKey) => AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l.anErrorOccurred,
                  subtitle: ErrorMapper.getErrorMessage(context, errorKey),
                ),
              DriverRevisionLoaded(:final requests) => requests.isEmpty
                  ? AppEmptyState(
                      icon: Icons.fact_check_outlined,
                      title: l.noRevisionRequests,
                      subtitle: l.noRevisionRequestsDesc,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _RevisionRequestCard(
                          revision: requests[index],
                          canEdit: canEdit,
                        );
                      },
                    ),
            };
          },
        ),
      ),
    );
  }
}

class _RevisionRequestCard extends StatelessWidget {
  final RevisionRequestModel revision;
  final bool canEdit;

  const _RevisionRequestCard({required this.revision, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fields = revision.displayFields(context);
    final message = revision.message ?? '';
    final createdAt = _formatDate(revision.createdAt);
    final resolved = revision.isResolved;
    final statusColor = resolved ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                resolved
                    ? Icons.check_circle_outline_rounded
                    : Icons.edit_note_rounded,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  resolved ? l.revisionResolved : l.revisionNeedsAction,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  resolved ? l.completed : l.pending,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l.fieldsRequested,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
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
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: context.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  createdAt != null
                      ? l.revisionCreatedAt(createdAt)
                      : l.revisionCreatedAt('-'),
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),

          if (canEdit && !resolved) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.driverProfile),
                icon: const Icon(Icons.person_rounded),
                label: Text(l.editProfile),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final date = value.toLocal();
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
