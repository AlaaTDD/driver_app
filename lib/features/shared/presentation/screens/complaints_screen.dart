import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../services/supabase_service.dart';
import '../../../shared/data/repositories/complaints_repository.dart';

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

  // Local state
  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;

  // Realtime
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
    setState(() { _loading = true; _page = 0; _hasMore = true; });
    try {
      final data = await _repo.getMyComplaintsPaged(page: 0, pageSize: _pageSize);
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
      final data = await _repo.getMyComplaintsPaged(page: nextPage, pageSize: _pageSize);
      if (mounted) {
        setState(() {
          _page = nextPage;
          final existingIds = _complaints.map((c) => c['id']).toSet();
          _complaints.addAll(data.where((c) => !existingIds.contains(c['id'])));
          _hasMore = data.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
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
        // Insert at top (newest first)
        _complaints.insert(0, Map<String, dynamic>.from(newRecord));
        _hasNewActivity = false; // it's already added
      });
    }
  }

  void _onRealtimeUpdate(PostgresChangePayload payload) {
    final updated = payload.newRecord;
    if (updated.isEmpty) return;
    final id = updated['id'];
    if (mounted) {
      setState(() {
        final idx = _complaints.indexWhere((c) => c['id'] == id);
        if (idx != -1) {
          _complaints[idx] = Map<String, dynamic>.from(updated);
        }
        // Show "new activity" badge if admin replied
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                            key: ValueKey(_complaints[i]['id']),
                            complaint: _complaints[i],
                            repo: _repo,
                            onRefresh: _initialLoad,
                            onComplaintUpdated: (updated) {
                              if (mounted) {
                                setState(() {
                                  final idx = _complaints.indexWhere(
                                      (c) => c['id'] == updated['id']);
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
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
    'pending'     => isAr ? 'قيد الانتظار' : 'Pending',
    'open'        => isAr ? 'مفتوحة' : 'Open',
    'in_progress' => isAr ? 'قيد المعالجة' : 'In Progress',
    'info_needed' => isAr ? 'يحتاج معلومات' : 'Info Needed',
    'resolved'    => isAr ? 'محلولة' : 'Resolved',
    'closed'      => isAr ? 'مغلقة' : 'Closed',
    _             => status,
  };
}

Color _statusColor(String status) => switch (status) {
  'pending' || 'open' => AppColors.warning,
  'in_progress'       => AppColors.info,
  'info_needed'       => AppColors.error,
  'resolved' || 'closed' => AppColors.success,
  _                   => AppColors.textDisabled,
};

String _formatDate(String? iso) {
  if (iso == null) return '';
  try {
    return DateFormat('dd/MM/yyyy – hh:mm a').format(DateTime.parse(iso).toLocal());
  } catch (_) { return iso; }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Complaint Card
// ─────────────────────────────────────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final ComplaintsRepository repo;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>) onComplaintUpdated;

  const _ComplaintCard({
    super.key,
    required this.complaint,
    required this.repo,
    required this.onRefresh,
    required this.onComplaintUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final status = complaint['status'] ?? 'pending';
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
              color: (isInfoNeeded ? AppColors.error : hasReply ? AppColors.info : AppColors.black)
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
                          complaint['title'] ?? '',
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
                          _formatDate(complaint['created_at']),
                          style: TextStyle(fontSize: 11, color: context.textDisabled),
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
                style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4),
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
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  if (isInfoNeeded) ...[
                    const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      'يحتاج معلومات منك',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700),
                    ),
                  ] else if (hasReply) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'رد جديد من الدعم',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w700),
                    ),
                  ] else
                    Text(
                      'اضغط لعرض المحادثة',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  const Spacer(),
                  const Icon(Icons.chevron_left_rounded, color: AppColors.primary, size: 18),
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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Thread Sheet  (Real-time inside the conversation too)
// ─────────────────────────────────────────────────────────────────────────────

class _ComplaintThreadSheet extends StatefulWidget {
  final Map<String, dynamic> complaint;
  final ComplaintsRepository repo;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>) onComplaintUpdated;

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

  List<Map<String, dynamic>> _thread = [];
  bool _threadLoading = true;
  late Map<String, dynamic> _complaint;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _complaint = Map<String, dynamic>.from(widget.complaint);
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
      final thread = await widget.repo.getComplaintThread(_complaint['id'].toString());
      if (mounted) {
        setState(() {
          _thread = thread;
          _threadLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _threadLoading = false);
    }
  }

  void _subscribeRealtime() {
    final complaintId = _complaint['id'].toString();
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
                _complaint = Map<String, dynamic>.from(updated);
              });
              widget.onComplaintUpdated(_complaint);
              _loadThread(); // reload thread when complaint is updated
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
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
        complaintId: _complaint['id'].toString(),
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
      await widget.repo.closeComplaint(_complaint['id'].toString());
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
    final status = _complaint['status'] ?? 'pending';
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
          // ── Handle ─────────────────────────────────────────────────
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
          const SizedBox(height: 14),

          // ── Title + Status ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _complaint['title'] ?? '',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(_complaint['created_at']),
                        style: TextStyle(fontSize: 11, color: context.textDisabled),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'فريق الدعم يحتاج معلومات إضافية منك — ردّ عليهم'
                          : 'Support needs more info from you — please reply',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
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
                        itemBuilder: (_, i) => _MessageBubble(msg: _thread[i]),
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
                      isAr ? 'إغلاق الشكوى نهائياً؟' : 'Close this complaint permanently?',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    child: Text(isAr ? 'نعم، أغلق' : 'Yes, Close'),
                  ),
                ],
              ),
            ),

          // ── Reply Bar ───────────────────────────────────────────────
          if (!isClosed)
            Container(
              padding: EdgeInsets.only(
                  left: 10, right: 10, top: 10, bottom: bottomPadding + 14),
              decoration: BoxDecoration(
                color: context.elevatedColor,
                border: Border(top: BorderSide(color: context.divColor)),
              ),
              child: Row(
                children: [
                  // Close button
                  if (status != 'pending' && status != 'open')
                    IconButton(
                      icon: Icon(Icons.check_circle_outline_rounded,
                          color: context.textDisabled, size: 22),
                      onPressed: () => setState(() => _showCloseConfirm = true),
                      tooltip: isAr ? 'إغلاق الشكوى' : 'Close complaint',
                    ),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(fontSize: 14, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: isAr ? 'اكتب ردك...' : 'Type your reply...',
                        hintStyle: TextStyle(color: context.textDisabled, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: context.bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: _sending ? null : _sendReply,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _sending
                            ? null
                            : const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _sending ? AppColors.primary.withValues(alpha: 0.4) : null,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: bottomPadding + 14, top: 12),
              child: Text(
                isAr ? '🔒 هذه الشكوى مغلقة' : '🔒 This complaint is closed',
                style: TextStyle(fontSize: 13, color: context.textDisabled),
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
  final Map<String, dynamic> msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg['sender_type'] == 'user';
    final isOriginal = msg['is_original'] == true;
    final message = msg['message'] ?? '';
    final dateStr = _formatDate(msg['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.14),
              child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                if (isOriginal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? '📝 الشكوى الأصلية'
                          : '📝 Original complaint',
                      style: TextStyle(
                          fontSize: 10,
                          color: context.textDisabled,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 4 : 18),
                      bottomRight: Radius.circular(isMe ? 18 : 4),
                    ),
                    border: Border.all(
                      color: isMe
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.success.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                        fontSize: 14, color: context.textPrimary, height: 1.45),
                  ),
                ),
                const SizedBox(height: 4),
                Text(dateStr,
                    style: TextStyle(fontSize: 10, color: context.textDisabled)),
              ],
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.success.withValues(alpha: 0.14),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppColors.success, size: 15),
            ),
          ],
        ],
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
        AppButton(text: l.submitComplaint, leadingIcon: Icons.add_rounded, onPressed: onAdd),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : context.elevatedColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : context.divColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.$3,
                            size: 14,
                            color: isSelected ? AppColors.primary : context.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          cat.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.primary : context.textSecondary,
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
