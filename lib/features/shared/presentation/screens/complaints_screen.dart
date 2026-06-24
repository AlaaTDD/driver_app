import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/models/complaint_message_model.dart';
import '../../../../core/models/complaint_model.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../shared/data/repositories/complaints_repository.dart';
import 'package:snapix/core/utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _repo = ComplaintsRepository();
  final _pageSize = 10;

  List<ComplaintModel> _complaints = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;

  RealtimeChannel? _channel;
  bool _hasNewActivity = false;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Initial Load ───────────────────────────────────────────────────
  Future<void> _initialLoad() async {
    setState(() {
      _loading = true;
      _page = 0;
      _hasMore = true;
    });
    try {
      final data =
          await _repo.getMyComplaintsPaged(page: 0, pageSize: _pageSize);
      if (mounted) {
        setState(() {
          _complaints = data;
          _loading = false;
          _hasMore = data.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Load More (Pagination) ─────────────────────────────────────────
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final data =
          await _repo.getMyComplaintsPaged(page: nextPage, pageSize: _pageSize);
      if (mounted) {
        setState(() {
          _page = nextPage;
          final existingIds = _complaints.map((c) => c.id).toSet();
          _complaints.addAll(data.where((c) => !existingIds.contains(c.id)));
          _hasMore = data.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (e, st) {
      AppLogger.warning('ComplaintsScreen: load more failed: $e');
      AppLogger.debug(st.toString());
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Supabase Realtime Subscription ────────────────────────────────
  void _subscribeRealtime() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    _channel = SupabaseService.client
        .channel('complaints-user-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'complaints',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onRealtimeInsert(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'complaints',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onRealtimeUpdate(payload),
        )
        .subscribe();
  }

  void _onRealtimeInsert(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;
    if (mounted) {
      setState(() {
        _complaints.insert(
          0,
          ComplaintModel.fromJson(Map<String, dynamic>.from(newRecord)),
        );
        _hasNewActivity = false;
      });
    }
  }

  void _onRealtimeUpdate(PostgresChangePayload payload) {
    final updated = payload.newRecord;
    if (updated.isEmpty) return;
    final id = updated['id'] as String?;
    if (mounted) {
      setState(() {
        final idx = _complaints.indexWhere((c) => c.id == id);
        if (idx != -1) {
          _complaints[idx] =
              ComplaintModel.fromJson(Map<String, dynamic>.from(updated));
        }
        final adminReply = updated['admin_reply'];
        if (adminReply != null && adminReply.toString().trim().isNotEmpty) {
          _hasNewActivity = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.complaints,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_hasNewActivity) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _initialLoad,
              color: AppColors.primary,
              child: _complaints.isEmpty
                  ? _EmptyState(l: l, onAdd: _showNew)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scroll) {
                        if (scroll.metrics.pixels >=
                            scroll.metrics.maxScrollExtent - 200) {
                          if (!_loadingMore && _hasMore) {
                            Future.microtask(() => _loadMore());
                          }
                        }
                        return false;
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: _complaints.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          if (i == _complaints.length) {
                            return _LoadMoreIndicator(
                              loading: _loadingMore,
                              onTap: _loadMore,
                            );
                          }
                          return _ComplaintCard(
                            key: ValueKey(_complaints[i].id),
                            complaint: _complaints[i],
                            repo: _repo,
                            onRefresh: _initialLoad,
                            onComplaintUpdated: (updated) {
                              if (mounted) {
                                setState(() {
                                  final idx = _complaints
                                      .indexWhere((c) => c.id == updated.id);
                                  if (idx != -1) _complaints[idx] = updated;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNew,
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l.submitComplaint,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showNew() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewComplaintSheet(repo: _repo, onSuccess: _initialLoad),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Load More Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _LoadMoreIndicator extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoadMoreIndicator({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'تحميل المزيد',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _statusLabel(String status, BuildContext ctx) {
  final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
  return switch (status) {
    'pending' => isAr ? 'قيد الانتظار' : 'Pending',
    'open' => isAr ? 'مفتوحة' : 'Open',
    'in_progress' => isAr ? 'قيد المعالجة' : 'In Progress',
    'info_needed' => isAr ? 'يحتاج معلومات' : 'Info Needed',
    'resolved' => isAr ? 'محلولة' : 'Resolved',
    'closed' => isAr ? 'مغلقة' : 'Closed',
    _ => status,
  };
}

Color _statusColor(String status) => switch (status) {
      'pending' || 'open' => AppColors.warning,
      'in_progress' => AppColors.info,
      'info_needed' => AppColors.error,
      'resolved' || 'closed' => AppColors.success,
      _ => AppColors.textDisabled,
    };

/// Icon matching each complaint status
IconData _statusIcon(String status) => switch (status) {
      'pending' || 'open' => Icons.hourglass_top_rounded,
      'in_progress' => Icons.sync_rounded,
      'info_needed' => Icons.help_outline_rounded,
      'resolved' => Icons.check_circle_rounded,
      'closed' => Icons.lock_rounded,
      _ => Icons.support_agent_rounded,
    };

String _formatDate(String? iso) {
  if (iso == null) return '';
  try {
    return DateFormat('dd/MM/yyyy – hh:mm a')
        .format(DateTime.parse(iso).toLocal());
  } catch (e, st) {
    AppLogger.warning('ComplaintsScreen: invalid date "$iso": $e');
    AppLogger.debug(st.toString());
    return iso;
  }
}

/// Short time format for chat bubbles (e.g. "3:45 PM")
String _formatTime(String? iso) {
  if (iso == null) return '';
  try {
    return DateFormat('h:mm a')
        .format(DateTime.parse(iso).toLocal());
  } catch (e) {
    return '';
  }
}

/// Day label for date separators (e.g. "اليوم", "أمس", "12 يونيو")
String _formatDayLabel(String? iso, bool isAr) {
  if (iso == null) return '';
  try {
    final date = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return isAr ? 'اليوم' : 'Today';
    if (msgDay == yesterday) return isAr ? 'أمس' : 'Yesterday';
    return DateFormat(isAr ? 'd MMMM' : 'MMM d').format(date);
  } catch (e) {
    return '';
  }
}

/// Check if two dates fall on the same calendar day
bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Complaint Card
// ─────────────────────────────────────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;
  final ComplaintsRepository repo;
  final VoidCallback onRefresh;
  final void Function(ComplaintModel) onComplaintUpdated;

  const _ComplaintCard({
    super.key,
    required this.complaint,
    required this.repo,
    required this.onRefresh,
    required this.onComplaintUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final status = complaint.status;
    final color = _statusColor(status);
    final hasReply = repo.hasUnreadAdminReply(complaint);
    final lastMsg = repo.getLastMessagePreview(complaint);
    final isInfoNeeded = status == 'info_needed';

    return GestureDetector(
      onTap: () => _openThread(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: context.elevatedColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isInfoNeeded
                ? AppColors.error.withValues(alpha: 0.4)
                : hasReply
                    ? AppColors.info.withValues(alpha: 0.4)
                    : context.divColor,
            width: (isInfoNeeded || hasReply) ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isInfoNeeded
                      ? AppColors.error
                      : hasReply
                          ? AppColors.info
                          : AppColors.black)
                  .withValues(alpha: isInfoNeeded || hasReply ? 0.08 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status bar
                  Container(
                    width: 4,
                    height: 48,
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.4)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(complaint.createdAt?.toIso8601String()),
                          style: TextStyle(
                              fontSize: 11, color: context.textDisabled),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: status),
                ],
              ),
            ),

            // ── Last message preview ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 14, 10),
              child: Text(
                lastMsg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: context.textSecondary, height: 1.4),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isInfoNeeded
                    ? AppColors.error.withValues(alpha: 0.06)
                    : hasReply
                        ? AppColors.info.withValues(alpha: 0.06)
                        : AppColors.primary.withValues(alpha: 0.03),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  if (isInfoNeeded) ...[
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.error),
                    const SizedBox(width: 6),
                    const Text(
                      'يحتاج معلومات منك',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w700),
                    ),
                  ] else if (hasReply) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.info, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'رد جديد من الدعم',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w700),
                    ),
                  ] else
                    Text(
                      'اضغط لعرض المحادثة',
                      style:
                          TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  const Spacer(),
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openThread(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComplaintThreadSheet(
        complaint: complaint,
        repo: repo,
        onRefresh: onRefresh,
        onComplaintUpdated: onComplaintUpdated,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Date Separator (between message groups)
// ─────────────────────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: context.divColor,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.elevatedColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.divColor, width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: context.divColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = _statusLabel(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Thread Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ComplaintThreadSheet extends StatefulWidget {
  final ComplaintModel complaint;
  final ComplaintsRepository repo;
  final VoidCallback onRefresh;
  final void Function(ComplaintModel) onComplaintUpdated;

  const _ComplaintThreadSheet({
    required this.complaint,
    required this.repo,
    required this.onRefresh,
    required this.onComplaintUpdated,
  });

  @override
  State<_ComplaintThreadSheet> createState() => _ComplaintThreadSheetState();
}

class _ComplaintThreadSheetState extends State<_ComplaintThreadSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _showCloseConfirm = false;

  List<ComplaintMessageModel> _thread = [];
  bool _threadLoading = true;
  late ComplaintModel _complaint;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _loadThread();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    setState(() => _threadLoading = true);
    try {
      final thread = await widget.repo.getComplaintThread(_complaint.id);
      if (mounted) {
        setState(() {
          _thread = thread;
          _threadLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e, st) {
      AppLogger.warning('ComplaintDetail: load thread failed: $e');
      AppLogger.debug(st.toString());
      if (mounted) setState(() => _threadLoading = false);
    }
  }

  void _subscribeRealtime() {
    final complaintId = _complaint.id;
    _channel = SupabaseService.client
        .channel('complaint-thread-$complaintId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'complaints',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: complaintId,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            if (updated.isEmpty) return;
            if (mounted) {
              setState(() {
                _complaint =
                    ComplaintModel.fromJson(Map<String, dynamic>.from(updated));
              });
              widget.onComplaintUpdated(_complaint);
              _loadThread();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.repo.submitUserReply(
        complaintId: _complaint.id,
        message: msg,
      );
      _ctrl.clear();
      await _loadThread();
      widget.onRefresh();
    } catch (e) {
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeComplaint() async {
    setState(() => _sending = true);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    try {
      await widget.repo.closeComplaint(_complaint.id);
      widget.onRefresh();
      if (mounted) {
        Navigator.pop(context);
        AppToast.success(isAr ? 'تم إغلاق الشكوى' : 'Complaint closed');
      }
    } catch (e) {
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final status = _complaint.status;
    final isClosed = status == 'closed';
    final needsInfo = status == 'info_needed';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.92,
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Grab handle ───────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header card with status accent ───────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: context.elevatedColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _statusColor(status).withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _statusColor(status).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _statusIcon(status),
                    color: _statusColor(status),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _complaint.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11, color: context.textDisabled),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDate(
                                  _complaint.createdAt?.toIso8601String()),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.textDisabled,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
              ],
            ),
          ),

          // ── Info Needed Banner ──────────────────────────────────────
          if (needsInfo)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'فريق الدعم يحتاج معلومات إضافية منك — ردّ عليهم'
                          : 'Support needs more info from you — please reply',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          Divider(color: context.divColor, height: 1),

          // ── Thread ──────────────────────────────────────────────────
          Expanded(
            child: _threadLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : _thread.isEmpty
                    ? Center(
                        child: Text(
                          isAr ? 'لا توجد رسائل' : 'No messages yet',
                          style: TextStyle(color: context.textDisabled),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        itemCount: _thread.length,
                        itemBuilder: (_, i) {
                          final msg = _thread[i];
                          // Show date separator when the day changes
                          final showSeparator = i == 0 ||
                              !_sameDay(
                                msg.createdAt,
                                _thread[i - 1].createdAt,
                              );
                          // Hide avatar when previous message is from the
                          // same sender (grouping consecutive messages)
                          final showAvatar = i == 0 ||
                              _thread[i - 1].senderType != msg.senderType ||
                              showSeparator;
                          return Column(
                            children: [
                              if (showSeparator)
                                _DateSeparator(
                                  label: _formatDayLabel(
                                    msg.createdAt?.toIso8601String(),
                                    isAr,
                                  ),
                                ),
                              _MessageBubble(
                                msg: msg,
                                showAvatar: showAvatar,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Close Confirm ───────────────────────────────────────────
          if (_showCloseConfirm)
            Container(
              color: AppColors.error.withValues(alpha: 0.07),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr
                          ? 'إغلاق الشكوى نهائياً؟'
                          : 'Close this complaint permanently?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showCloseConfirm = false),
                    child: Text(isAr ? 'لا' : 'No',
                        style: const TextStyle(color: AppColors.primary)),
                  ),
                  ElevatedButton(
                    onPressed: _sending ? null : _closeComplaint,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8)),
                    child: Text(isAr ? 'نعم، أغلق' : 'Yes, Close'),
                  ),
                ],
              ),
            ),

          // ── Reply Bar ───────────────────────────────────────────────
          if (!isClosed)
            Container(
              padding: EdgeInsets.only(
                  left: 10, right: 10, top: 8, bottom: bottomPadding + 10),
              decoration: BoxDecoration(
                color: context.elevatedColor,
                border: Border(
                  top: BorderSide(
                    color: context.divColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Close button (rounded icon style)
                  if (status != 'pending' && status != 'open')
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: context.bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.divColor),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.check_circle_outline_rounded,
                            color: context.textSecondary, size: 20),
                        onPressed: _sending
                            ? null
                            : () => setState(() => _showCloseConfirm = true),
                        tooltip: isAr ? 'إغلاق الشكوى' : 'Close complaint',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 42,
                          minHeight: 42,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Text input — grows with content
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: context.bgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _ctrl.text.trim().isNotEmpty
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : context.divColor,
                          width: 1.2,
                        ),
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _ctrl,
                        builder: (context, value, child) {
                          return TextField(
                            controller: _ctrl,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendReply(),
                            style: TextStyle(
                              fontSize: 14.5,
                              color: context.textPrimary,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: isAr
                                  ? 'اكتب رسالتك...'
                                  : 'Type your message...',
                              hintStyle: TextStyle(
                                color: context.textDisabled,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              isDense: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button — animated, enlarges when there's text
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _ctrl,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: (_sending || !hasText) ? null : _sendReply,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: _sending || !hasText
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryDark
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: _sending
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : !hasText
                                    ? context.bgColor
                                    : null,
                            shape: BoxShape.circle,
                            border: _sending || hasText
                                ? null
                                : Border.all(color: context.divColor),
                            boxShadow: _sending || !hasText
                                ? []
                                : [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: hasText
                                      ? AppColors.white
                                      : context.textDisabled,
                                  size: 20,
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.only(
                  left: 16, right: 16, bottom: bottomPadding + 14, top: 14),
              decoration: BoxDecoration(
                color: context.elevatedColor,
                border: Border(
                  top: BorderSide(color: context.divColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded,
                      size: 14, color: context.textDisabled),
                  const SizedBox(width: 6),
                  Text(
                    isAr ? 'هذه الشكوى مغلقة' : 'This complaint is closed',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textDisabled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Message Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ComplaintMessageModel msg;
  final bool showAvatar;
  const _MessageBubble({required this.msg, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.senderType == 'user';
    final isOriginal = msg.isOriginal;
    final message = msg.message;
    final timeStr = _formatTime(msg.createdAt?.toIso8601String());
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: EdgeInsets.only(
        bottom: isOriginal ? 24 : 14,
        top: isOriginal ? 8 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Avatar (left for admin) ──────────────
          if (!isMe) ...[
            if (showAvatar)
              const _Avatar(isMe: false, isOriginal: false)
            else
              const SizedBox(width: 36),
            const SizedBox(width: 10),
          ],

          // ── Bubble + label column ─────────────────────────────────
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Original complaint card — special style
                if (isOriginal) ...[
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      color: AppColors.warning.withValues(alpha: 0.06),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded,
                                  size: 14, color: AppColors.warning),
                              const SizedBox(width: 6),
                              Text(
                                isAr
                                    ? 'الشكوى الأصلية'
                                    : 'Original Complaint',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.textDisabled,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Body
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: context.textPrimary,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Regular chat bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.74,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      // Admin → solid gradient; User → soft tinted
                      gradient: isMe
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.secondary, AppColors.secondaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isMe
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        // user is on the RIGHT → sharp tail at bottom-RIGHT
                        // admin is on the LEFT  → sharp tail at bottom-LEFT
                        bottomLeft:  Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      border: isMe
                          ? Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.18),
                              width: 1.2,
                            )
                          : null,
                      boxShadow: isMe
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.secondary
                                    .withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sender name
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            isMe
                                ? (isAr ? 'أنت' : 'You')
                                : (isAr ? 'فريق الدعم' : 'Support'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isMe
                                  ? AppColors.primary
                                  : AppColors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        // Message text
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: isMe
                                ? context.textPrimary
                                : AppColors.white,
                            height: 1.5,
                          ),
                        ),
                        // Timestamp
                        if (timeStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: isMe
                                      ? context.textDisabled
                                      : AppColors.white.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isMe
                                        ? context.textDisabled
                                        : AppColors.white
                                            .withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Avatar (right for user) ──────────────────────────────
          if (isMe) ...[
            const SizedBox(width: 10),
            if (showAvatar)
              _Avatar(
                isMe: true,
                isOriginal: isOriginal,
              )
            else
              const SizedBox(width: 36),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Avatar (gradient circle for user / admin)
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final bool isMe;
  final bool isOriginal;
  const _Avatar({required this.isMe, required this.isOriginal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: isMe
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isMe ? AppColors.primary : AppColors.secondary)
                .withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isOriginal
            ? Icons.flag_rounded
            : isMe
                ? Icons.person_rounded
                : Icons.support_agent_rounded,
        color: AppColors.white,
        size: 17,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback onAdd;
  const _EmptyState({required this.l, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded,
                size: 48, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l.complaints,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.textPrimary),
        ),
        const SizedBox(height: 10),
        Text(
          l.describeIssueDetail,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.textSecondary),
        ),
        const SizedBox(height: 32),
        AppButton(
            text: l.submitComplaint,
            leadingIcon: Icons.add_rounded,
            onPressed: onAdd),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  New Complaint Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NewComplaintSheet extends StatefulWidget {
  final ComplaintsRepository repo;
  final VoidCallback onSuccess;
  const _NewComplaintSheet({required this.repo, required this.onSuccess});

  @override
  State<_NewComplaintSheet> createState() => _NewComplaintSheetState();
}

class _NewComplaintSheetState extends State<_NewComplaintSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'general';
  bool _loading = false;

  final _categories = [
    ('general', 'عام', Icons.public_rounded),
    ('trip', 'رحلة', Icons.directions_car_rounded),
    ('payment', 'دفع', Icons.payment_rounded),
    ('driver', 'سائق', Icons.person_rounded),
    ('app', 'تطبيق', Icons.phone_android_rounded),
    ('other', 'أخرى', Icons.more_horiz_rounded),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      AppToast.error(l.pleaseFillAllFields);
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.repo.submitComplaint(
        title: _titleCtrl.text,
        description: _descCtrl.text,
        category: _category,
      );
      if (!mounted) return;
      AppToast.success(l.successComplaintSent);
      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BottomSheetContainer(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.submitComplaint,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(l.describeIssueDetail,
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 20),

            // Category
            Text(
              isAr ? 'نوع الشكوى' : 'Category',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _category == cat.$1;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat.$1),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : context.elevatedColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : context.divColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.$3,
                            size: 14,
                            color: isSelected
                                ? AppColors.primary
                                : context.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          cat.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _titleCtrl,
              label: l.titleLabel,
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _descCtrl,
              label: l.descriptionLabel,
              maxLines: 5,
              prefixIcon: Icons.description_rounded,
            ),
            const SizedBox(height: 24),

            AppButton(
              text: l.send,
              onPressed: _loading ? null : _submit,
              isLoading: _loading,
              leadingIcon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
