import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();

    // If a direct target is provided, skip the list and open chat immediately
    if (widget.tripId != null && widget.tripId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openChat(tripId: widget.tripId);
      });
    } else if (widget.otherUserId != null &&
        widget.otherUserId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openChat(otherUserId: widget.otherUserId);
      });
    }
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final data = await _repo.loadConversations();
    if (!mounted) return;
    setState(() {
      _conversations = data;
      _isLoading = false;
    });
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
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _conversations.isEmpty
              ? _buildEmpty(context, l)
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.divColor,
                      indent: 78,
                    ),
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      return _ConversationTile(
                        name: conv['other_user_name'] as String? ?? '',
                        lastMessage: conv['last_message'] as String? ?? '',
                        lastTime: conv['last_message_at'] as String?,
                        role: conv['other_user_role'] as String? ?? 'user',
                        isRead: conv['is_me_sender'] as bool? ?? true
                            ? true
                            : conv['is_read'] as bool? ?? false,
                        onTap: () => _openChat(
                          otherUserId: conv['other_user_id'] as String,
                          otherName: conv['other_user_name'] as String?,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 52, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            l.noMessages,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.startChat,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String? lastTime;
  final String role;
  final bool isRead;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    required this.role,
    required this.isRead,
    required this.onTap,
  });

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = role == 'driver';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    isDriver ? Icons.drive_eta_rounded : Icons.person_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.bgColor, width: 2),
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
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(lastTime),
                        style: TextStyle(
                          color: isRead ? context.textSecondary : AppColors.primary,
                          fontSize: 12,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isRead
                                ? context.textSecondary
                                : context.textPrimary,
                            fontSize: 13,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
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
  final _repo = MessagesRepository();

  String _otherName = '';
  String? _resolvedOtherUserId;

  bool get _isTripChat =>
      widget.tripId != null && widget.tripId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _otherName = widget.otherUserName ?? '';
    _init();
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
      // Resolve participant name if not passed
      if (_otherName.isEmpty) {
        final tripData =
            await _repo.fetchTripParticipants(widget.tripId!);
        if (tripData != null) {
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
      // Fetch name if not passed
      if (_otherName.isEmpty) {
        final info = await _repo.fetchUserInfo(_resolvedOtherUserId!);
        if (info != null && mounted) {
          setState(() => _otherName = info['name'] as String? ?? '');
        }
      }

      final messages =
          await _repo.loadDirectMessages(_resolvedOtherUserId!);
      if (!mounted) return;
      _setMessages(messages);

      // Subscribe to realtime
      _realtimeSub = _repo
          .subscribeToDirectMessages(_resolvedOtherUserId!)
          .listen((msgs) => _setMessages(msgs));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _setMessages(List<MessageModel> messages) {
    if (!mounted) return;
    final myId = SupabaseService.currentUser?.id;
    setState(() {
      _isLoading = false;
      _displayMessages = messages.reversed.map((m) => _ChatDisplayItem(
        text: m.content,
        isMe: m.senderId == myId,
        createdAt: m.createdAt,
      )).toList();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
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
        );
      } else {
        await _repo.sendDirectMessage(
          receiverId: _resolvedOtherUserId!,
          text: text,
          senderName: senderName,
          newMessageFrom: (name) => l.newMessageFrom(name),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _displayMessages.removeWhere((m) => m.isSending && m.text == text));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.failedSendMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _otherName.isNotEmpty ? _otherName : l.theChat,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l.online,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textSecondary),
            const SizedBox(height: 16),
            Text(l.failedLoadMessages,
                style: TextStyle(color: context.textPrimary, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: Text(l.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      );
    }
    if (_displayMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              l.startChat,
              style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _otherName.isNotEmpty ? 'Say hi to $_otherName! 👋' : '',
              style: TextStyle(
                  color: context.textSecondary.withValues(alpha: 0.5),
                  fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _displayMessages.length,
      itemBuilder: (context, index) {
        final msg = _displayMessages[index];
        return _ChatBubble(
          message: msg.text,
          time: _formatTime(msg.createdAt),
          isMe: msg.isMe,
          isSending: msg.isSending,
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context, AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: context.elevatedColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 16,
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
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: context.textSecondary.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: l.typeMessage,
                    hintStyle: TextStyle(
                        color: context.textSecondary.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sendMessage,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMe,
    this.isSending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.person, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : context.elevatedColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : context.textPrimary,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.8)
                              : context.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isSending
                              ? Icons.access_time
                              : Icons.done_all,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _ChatDisplayItem {
  final String text;
  final bool isMe;
  final DateTime? createdAt;
  final bool isSending;

  const _ChatDisplayItem({
    required this.text,
    required this.isMe,
    this.createdAt,
    this.isSending = false,
  });
}
