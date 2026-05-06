import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../services/supabase_service.dart';
import 'data/messages_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConversationsScreen — list of all chats for the current user
// ─────────────────────────────────────────────────────────────────────────────
class ConversationsScreen extends StatefulWidget {
  final String? tripId; // if set, open trip chat directly
  final String? otherUserId; // if set, open direct chat directly

  const ConversationsScreen({super.key, this.tripId, this.otherUserId});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _repo = MessagesRepository();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  StreamSubscription? _convRealtimeSub;
  StreamSubscription? _payloadSub;
  final Map<String, bool> _onlineMap = {};
  Timer? _onlineTimer;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();

    if (widget.tripId != null && widget.tripId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openChat(tripId: widget.tripId);
      });
    } else if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openChat(otherUserId: widget.otherUserId);
      });
    } else {
      _loadConversations();
      _subscribeToConversationsRealtime();
      _subscribeToPayloads();
      _startPresenceHeartbeat();
    }
  }

  @override
  void dispose() {
    _convRealtimeSub?.cancel();
    _payloadSub?.cancel();
    _onlineTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  // ─── Presence: update last_seen every 10s while in conversation list ───
  void _startPresenceHeartbeat() {
    _repo.ensureMyPresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _repo.ensureMyPresence();
    });
  }

  // ─── Realtime: targeted optimistic update (no shimmer reload) ───
  void _subscribeToPayloads() {
    _payloadSub = _repo.watchConversationPayloads().listen((msg) {
      if (!mounted) return;
      _handleRealtimeMessage(msg);
    });
  }

  void _handleRealtimeMessage(Map<String, dynamic> msg) {
    final myId = SupabaseService.currentUser?.id;
    if (myId == null) return;

    final senderId = msg['sender_id'] as String?;
    final receiverId = msg['receiver_id'] as String?;
    final otherId = (senderId == myId) ? receiverId : senderId;
    if (otherId == null || senderId == null || receiverId == null) return;

    final content = msg['content'] as String? ?? '';
    final createdAt = msg['created_at'] as String?;
    final isRead = msg['is_read'] as bool? ?? false;
    final deletedByMe = (senderId == myId)
        ? (msg['deleted_by_sender'] as bool? ?? false)
        : (msg['deleted_by_receiver'] as bool? ?? false);

    // Soft-delete by me → full reload to get previous message
    if (deletedByMe) {
      _loadConversations();
      return;
    }

    setState(() {
      final idx = _conversations.indexWhere(
        (c) => c['other_user_id'] == otherId,
      );

      if (idx >= 0) {
        final conv = _conversations[idx];
        final wasMeSender = senderId == myId;
        final unreadIncrement = (!wasMeSender && !isRead) ? 1 : 0;

        _conversations[idx] = {
          ...conv,
          'last_message': content,
          'last_message_at': createdAt ?? conv['last_message_at'],
          'is_me_sender': wasMeSender,
          'is_read': wasMeSender ? true : isRead,
          'unread_count': (conv['unread_count'] as int? ?? 0) + unreadIncrement,
        };

        // Move updated conversation to top by re-sorting
        _conversations.sort((a, b) {
          final aTime = a['last_message_at'] as String? ?? '';
          final bTime = b['last_message_at'] as String? ?? '';
          return bTime.compareTo(aTime);
        });
      } else {
        // Brand new conversation — fetch full list once
        _loadConversations();
      }
    });
  }

  void _subscribeToConversationsRealtime() {
    _convRealtimeSub = _repo.watchConversations().listen((_) {
      if (!mounted) return;
      // Payload stream handles targeted updates; this is a safety fallback
      // for events that might slip through (e.g., trip messages)
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final data = await _repo.loadConversations();
    if (!mounted) return;
    setState(() {
      _conversations = data;
      _isLoading = false;
    });
    _fetchOnlineStatuses();
  }

  Future<void> _fetchOnlineStatuses() async {
    if (_conversations.isEmpty) return;
    final userIds = _conversations
        .map((c) => c['other_user_id'] as String?)
        .where((id) => id != null)
        .toList();
    if (userIds.isEmpty) return;
    try {
      final result = await SupabaseService.client
          .from('user_presence')
          .select('user_id, last_seen')
          .inFilter('user_id', userIds);
      final now = DateTime.now().toUtc();
      final Map<String, bool> updated = {};
      for (final row in result) {
        final uid = row['user_id'] as String?;
        final ls = row['last_seen'] as String?;
        if (uid == null || ls == null) continue;
        final lastSeen = DateTime.tryParse(ls)?.toUtc();
        if (lastSeen == null) continue;
        updated[uid] = now.difference(lastSeen).inSeconds < 30;
      }
      if (mounted) setState(() => _onlineMap.addAll(updated));
    } catch (e) {
      debugPrint('❌ _fetchOnlineStatuses: $e');
    }
    // Refresh every 10s (was 30s — too slow for UX)
    _onlineTimer?.cancel();
    _onlineTimer = Timer(const Duration(seconds: 10), _fetchOnlineStatuses);
  }

  void _openChat({String? tripId, String? otherUserId, String? otherName}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          tripId: tripId,
          otherUserId: otherUserId,
          otherUserName: otherName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text(
          l.messages,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: context.divColor,
          ),
        ),
      ),
      body: _isLoading
          ? _buildShimmerList()
          : _conversations.isEmpty
              ? _buildEmpty(context, l)
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: AppColors.primary,
                  backgroundColor: context.elevatedColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final isMeSender =
                          conv['is_me_sender'] as bool? ?? true;
                      final convIsRead = isMeSender
                          ? true
                          : (conv['is_read'] as bool? ?? false);
                      final otherId = conv['other_user_id'] as String;
                      return _ConversationTile(
                        name: conv['other_user_name'] as String? ?? '',
                        lastMessage:
                            conv['last_message'] as String? ?? '',
                        lastTime: conv['last_message_at'] as String?,
                        role: conv['other_user_role'] as String? ?? 'user',
                        avatarUrl: conv['other_user_avatar'] as String?,
                        isRead: convIsRead,
                        isMeSender: isMeSender,
                        unreadCount: conv['unread_count'] as int? ?? 0,
                        isOnline: _onlineMap[otherId] ?? false,
                        onTap: () => _openChat(
                          otherUserId: otherId,
                          otherName:
                              conv['other_user_name'] as String?,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 8,
      itemBuilder: (_, __) => const _ShimmerTile(),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.noMessages,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.startChat,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer loading tile
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerTile extends StatefulWidget {
  const _ShimmerTile();

  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: context.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BoxDecoration(
                          color: context.textSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: context.textSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation list tile (modern)
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String? lastTime;
  final String role;
  final String? avatarUrl;
  final bool isRead;
  final bool isMeSender;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    required this.role,
    this.avatarUrl,
    required this.isRead,
    required this.isMeSender,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.onTap,
  });

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(dt.year, dt.month, dt.day);
      if (msgDate == today) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (msgDate == yesterday) return 'أمس';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = isMeSender ? 'أنت: $lastMessage' : lastMessage;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? Icon(
                          role == 'driver'
                              ? Icons.drive_eta_rounded
                              : Icons.person_rounded,
                          color: AppColors.primary,
                          size: 28,
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.bgColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(lastTime),
                        style: TextStyle(
                          color: isRead
                              ? context.textSecondary
                              : AppColors.primary,
                          fontSize: 12,
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isRead
                                ? context.textSecondary
                                : context.textPrimary,
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MessagesScreen — the actual chat UI (direct or trip)
// ─────────────────────────────────────────────────────────────────────────────
class MessagesScreen extends StatefulWidget {
  final String? tripId;
  final String? otherUserId;
  final String? otherUserName;

  const MessagesScreen({
    super.key,
    this.tripId,
    this.otherUserId,
    this.otherUserName,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<_ChatDisplayItem> _displayMessages = [];
  bool _isLoading = true;
  String? _error;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _realtimeSub;
  StreamSubscription? _onlineSub;
  Timer? _presenceTimer;
  final _repo = MessagesRepository();
  DateTime? _lastSentAt;

  String _otherName = '';
  String? _resolvedOtherUserId;
  String? _otherAvatarUrl;
  bool _isOtherOnline = false;
  bool _showScrollToBottom = false;
  bool _canSend = true;

  bool get _isTripChat =>
      widget.tripId != null && widget.tripId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _otherName = widget.otherUserName ?? '';
    _scrollController.addListener(() {
      final show = _scrollController.offset > 200;
      if (_showScrollToBottom != show) {
        setState(() => _showScrollToBottom = show);
      }
    });
    _init();
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    // Immediate presence update on entering chat
    _repo.ensureMyPresence();
    // Heartbeat every 10 seconds while in chat
    _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _repo.ensureMyPresence();
    });
  }

  Future<void> _init() async {
    if (_isTripChat) {
      await _initTripChat();
    } else {
      await _initDirectChat();
    }
  }

  Future<void> _initTripChat() async {
    try {
      // Check if trip is still active
      final tripData = await _repo.fetchTripParticipants(widget.tripId!);
      if (tripData != null) {
        final tripStatus = tripData['status'] as String?;
        final activeStatuses = ['pending', 'accepted', 'in_progress', 'arrived', 'picked_up'];
        if (tripStatus == null || !activeStatuses.contains(tripStatus)) {
          if (mounted) setState(() => _canSend = false);
        }
      }

      // Resolve participant name if not passed
      if (_otherName.isEmpty && tripData != null) {
        final me = SupabaseService.currentUser?.id;
        final otherId = (tripData['user_id'] == me)
            ? tripData['driver_id']
            : tripData['user_id'];
        if (otherId != null) {
          _resolvedOtherUserId = otherId as String;
          final name = await _repo.fetchUserName(otherId);
          if (mounted && name != null) {
            setState(() => _otherName = name);
          }
        }
      }

      final messages = await _repo.loadTripMessages(widget.tripId!);
      if (!mounted) return;
      _setMessages(messages);

      // Subscribe to realtime
      _realtimeSub = _repo
          .subscribeToTripMessages(widget.tripId!)
          .listen((msgs) => _setMessages(msgs));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _initDirectChat() async {
    _resolvedOtherUserId = widget.otherUserId;
    if (_resolvedOtherUserId == null) {
      setState(() => _error = 'No conversation target');
      return;
    }

    try {
      // Fetch name + avatar if not passed
      if (_otherName.isEmpty || _otherAvatarUrl == null) {
        final info = await _repo.fetchUserInfo(_resolvedOtherUserId!);
        if (info != null && mounted) {
          setState(() {
            _otherName = info['name'] as String? ?? '';
            _otherAvatarUrl = info['avatar_url'] as String?;
          });
        }
      }

      // Check active trip guard (for direct messages only)
      if (!mounted) return;
      final hasActiveTrip =
          await _repo.hasActiveTripWith(_resolvedOtherUserId!);
      if (!mounted) return;
      if (!hasActiveTrip) {
        setState(() => _canSend = false);
      }

      final messages =
          await _repo.loadDirectMessages(_resolvedOtherUserId!);
      if (!mounted) return;
      _setMessages(messages);

      // Subscribe to realtime
      _realtimeSub = _repo
          .subscribeToDirectMessages(_resolvedOtherUserId!)
          .listen((msgs) => _setMessages(msgs));

      // Subscribe to online status (insert/update/delete)
      _watchOnlineStatus(_resolvedOtherUserId!);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _watchOnlineStatus(String userId) {
    _onlineSub?.cancel();
    SupabaseService.client
        .channel('online-status-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          callback: (payload) {
            final eventType = payload.eventType;
            if (eventType == PostgresChangeEvent.delete) {
              if (mounted) setState(() => _isOtherOnline = false);
              return;
            }
            final newRow = payload.newRecord;
            if (newRow.isNotEmpty && newRow['user_id'] == userId) {
              _updateOnlineFromRecord(newRow);
            }
          },
        )
        .subscribe();

    // Initial check + periodic refresh every 10s (as fallback for missed events)
    _fetchOnlineStatus(userId);
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchOnlineStatus(userId);
    });
  }

  Timer? _onlineRefreshTimer;

  void _fetchOnlineStatus(String userId) {
    SupabaseService.client
        .from('user_presence')
        .select('last_seen')
        .eq('user_id', userId)
        .maybeSingle()
        .then((result) {
      if (result != null) {
        _updateOnlineFromRecord(result);
      } else if (mounted) {
        setState(() => _isOtherOnline = false);
      }
    });
  }

  void _updateOnlineFromRecord(Map<String, dynamic> record) {
    final lastSeenStr = record['last_seen'] as String?;
    if (lastSeenStr == null) {
      if (mounted) setState(() => _isOtherOnline = false);
      return;
    }
    final lastSeen = DateTime.tryParse(lastSeenStr)?.toUtc();
    if (lastSeen == null) {
      if (mounted) setState(() => _isOtherOnline = false);
      return;
    }
    final now = DateTime.now().toUtc();
    final isOnline = now.difference(lastSeen).inSeconds < 30;
    if (mounted) setState(() => _isOtherOnline = isOnline);
  }

  void _setMessages(List<MessageModel> messages) {
    if (!mounted) return;
    final myId = SupabaseService.currentUser?.id;
    final hasNewIncoming = messages.any((m) => m.senderId != myId && !m.isRead);

    setState(() {
      _isLoading = false;
      _displayMessages = messages.reversed.map((m) => _ChatDisplayItem(
        text: m.content,
        isMe: m.senderId == myId,
        createdAt: m.createdAt,
        isRead: m.isRead,
      )).toList();
    });

    // Mark incoming realtime messages as read when chat is open
    if (hasNewIncoming && _resolvedOtherUserId != null) {
      _repo.markAsRead(_resolvedOtherUserId!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _realtimeSub?.cancel();
    _onlineSub?.cancel();
    _presenceTimer?.cancel();
    _onlineRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_resolvedOtherUserId == null && !_isTripChat) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا يمكن إرسال الرسالة: لم يتم تحديد المستقبل'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!_canSend) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('لا يمكن إرسال الرسائل إلا أثناء رحلة نشطة'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_lastSentAt != null &&
        DateTime.now().difference(_lastSentAt!) <
            const Duration(seconds: 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorRateLimit)),
      );
      return;
    }
    _lastSentAt = DateTime.now();
    _messageController.clear();
    HapticFeedback.lightImpact();

    // Optimistic UI
    final optimistic = _ChatDisplayItem(
        text: text, isMe: true, createdAt: DateTime.now(), isSending: true);
    setState(() => _displayMessages.insert(0, optimistic));

    try {
      final l = AppLocalizations.of(context)!;
      final senderName =
          await _repo.fetchCurrentUserName() ?? l.newMessage;
      if (!mounted) return;

      if (_isTripChat) {
        await _repo.sendTripMessageWithNotification(
          tripId: widget.tripId!,
          text: text,
          senderName: senderName,
          newMessageFrom: (name) => l.newMessageFrom(name),
          defaultDriverName: l.defaultDriver,
        );
      } else {
        await _repo.sendDirectMessage(
          receiverId: _resolvedOtherUserId!,
          text: text,
          senderName: senderName,
          newMessageFrom: (name) => l.newMessageFrom(name),
          defaultUserName: l.defaultUser,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _displayMessages
            .removeWhere((m) => m.isSending && m.text == text));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.failedSendMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(DateTime dt, AppLocalizations l) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) return l.today;
    if (msgDate == yesterday) return 'أمس';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<_ChatDisplayItem> _buildItemsWithDateSeparators(AppLocalizations l) {
    final items = <_ChatDisplayItem>[];
    DateTime? lastDate;
    for (final msg in _displayMessages) {
      final dt = msg.createdAt;
      if (dt != null) {
        final date = DateTime(dt.year, dt.month, dt.day);
        if (lastDate == null || date != lastDate) {
          items.add(_ChatDisplayItem(
            text: _formatDateHeader(dt, l),
            isMe: false,
            isDateHeader: true,
          ));
          lastDate = date;
        }
      }
      items.add(msg);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.elevatedColor,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leadingWidth: 48,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: _otherAvatarUrl != null &&
                          _otherAvatarUrl!.isNotEmpty
                      ? NetworkImage(_otherAvatarUrl!)
                      : null,
                  child: _otherAvatarUrl == null ||
                          _otherAvatarUrl!.isEmpty
                      ? const Icon(Icons.person_rounded,
                          size: 20, color: AppColors.primary)
                      : null,
                ),
                if (_isOtherOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.elevatedColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherName.isNotEmpty ? _otherName : l.theChat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _isOtherOnline ? l.online : 'غير متصل',
                    style: TextStyle(
                      color: _isOtherOnline ? AppColors.success : context.textSecondary.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(l)),
          _buildInputBar(context, l),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 36, color: AppColors.error),
              ),
              const SizedBox(height: 20),
              Text(
                l.failedLoadMessages,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(l.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_displayMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              l.startChat,
              style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _otherName.isNotEmpty ? '${l.startChat} $_otherName!' : '',
              style: TextStyle(
                  color: context.textSecondary.withValues(alpha: 0.5),
                  fontSize: 14),
            ),
          ],
        ),
      );
    }
    final items = _buildItemsWithDateSeparators(l);
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          physics: const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.isDateHeader) {
              return _DateHeader(text: item.text);
            }
            return _ChatBubble(
              message: item.text,
              time: _formatTime(item.createdAt),
              isMe: item.isMe,
              isSending: item.isSending,
              isRead: item.isRead,
              avatarUrl: !item.isMe ? _otherAvatarUrl : null,
            );
          },
        ),
        if (_showScrollToBottom)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'scrollToBottom',
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildInputBar(BuildContext context, AppLocalizations l) {
    final isLocked = !_canSend;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.elevatedColor,
            context.bgColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : 20,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isLocked
                      ? context.bgColor.withValues(alpha: 0.4)
                      : context.bgColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isLocked
                        ? context.textSecondary.withValues(alpha: 0.06)
                        : context.textSecondary.withValues(alpha: 0.1),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !isLocked,
                  style: TextStyle(
                    color: isLocked
                        ? context.textSecondary.withValues(alpha: 0.35)
                        : context.textPrimary,
                    fontSize: 15,
                    height: 1.3,
                  ),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 5,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: isLocked ? 'الدردشة مغلقة — لا توجد رحلة نشطة' : l.typeMessage,
                    hintStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _AnimatedSendButton(
              isLocked: isLocked,
              onTap: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated send button with scale + glow
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedSendButton extends StatefulWidget {
  final bool isLocked;
  final VoidCallback onTap;

  const _AnimatedSendButton({required this.isLocked, required this.onTap});

  @override
  State<_AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<_AnimatedSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.85,
      upperBound: 1.0,
    );
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLocked ? null : (_) => _controller.reverse(),
      onTapUp: widget.isLocked
          ? null
          : (_) {
              _controller.forward();
              widget.onTap();
            },
      onTapCancel: widget.isLocked ? null : () => _controller.forward(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: widget.isLocked
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: widget.isLocked ? Colors.grey.shade400 : null,
                shape: BoxShape.circle,
                boxShadow: widget.isLocked
                    ? null
                    : const [
                        BoxShadow(
                          color: Color.fromRGBO(37, 99, 235, 0.45),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(13),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMe;
  final bool isSending;
  final bool isRead;
  final String? avatarUrl;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMe,
    this.isSending = false,
    this.isRead = false,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? const Icon(Icons.person_rounded,
                      size: 18, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : context.elevatedColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: Radius.circular(isMe ? 24 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color.fromRGBO(37, 99, 235, 0.22)
                            : (context.isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.06)),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: isMe ? Colors.white : context.textPrimary,
                          fontSize: 15.5,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : context.textSecondary.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            if (isSending)
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color:
                                      Colors.white.withValues(alpha: 0.8),
                                ),
                              )
                            else
                              _ReadStatusIcon(isRead: isRead),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 30),
        ],
      ),
    );
  }
}

class _ReadStatusIcon extends StatelessWidget {
  final bool isRead;
  const _ReadStatusIcon({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return isRead
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: -4),
              Icon(Icons.done_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.95)),
            ],
          )
        : Icon(Icons.done_rounded,
            size: 14, color: Colors.white.withValues(alpha: 0.7));
  }
}

class _ChatDisplayItem {
  final String text;
  final bool isMe;
  final DateTime? createdAt;
  final bool isSending;
  final bool isRead;
  final bool isDateHeader;

  const _ChatDisplayItem({
    required this.text,
    required this.isMe,
    this.createdAt,
    this.isSending = false,
    this.isRead = false,
    this.isDateHeader = false,
  });
}

class _DateHeader extends StatelessWidget {
  final String text;
  const _DateHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
