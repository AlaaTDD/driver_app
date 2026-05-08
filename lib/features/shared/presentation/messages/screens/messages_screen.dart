import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart' as intl;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import '../../../../../core/models/message_model.dart';
import '../../../../../services/supabase_service.dart';
import '../bloc/messages_cubit.dart';
import '../bloc/messages_state.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class MessagesScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = MessagesCubit();
        if (tripId != null && tripId!.isNotEmpty) {
          cubit.initTripChat(tripId!);
        } else if (otherUserId != null && otherUserId!.isNotEmpty) {
          cubit.initDirectChat(otherUserId!, otherUserName: otherUserName);
        }
        return cubit;
      },
      child: _MessagesView(
        tripId: tripId,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State holder
// ─────────────────────────────────────────────────────────────────────────────
class _MessagesView extends StatefulWidget {
  final String? tripId;
  final String? otherUserId;
  final String? otherUserName;

  const _MessagesView({
    this.tripId,
    this.otherUserId,
    this.otherUserName,
  });

  @override
  State<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<_MessagesView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  Timer? _typingTimer;
  String? _cachedOtherUserId;
  String? _cachedTripId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
  }

  bool get _hasMore {
    final state = context.read<MessagesCubit>().state;
    if (state is MessagesChatLoaded) return state.hasMore;
    return false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore) {
      context.read<MessagesCubit>().loadMoreMessages();
    }
  }

  void _onTextChanged() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context
            .read<MessagesCubit>()
            .updateTyping(_textController.text.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(BuildContext context, TextEditingController controller,
      MessagesCubit cubit) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (_cachedOtherUserId == null || _cachedOtherUserId!.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    cubit.sendMessage(
      text,
      _cachedOtherUserId!,
      tripId: _cachedTripId,
      newMessageFrom: (name) => l10n.newMessageFrom(name),
    );
    controller.clear();
    cubit.updateTyping(false);
    HapticFeedback.lightImpact();
    _scrollToBottom();
  }

  void _showMessageOptions(BuildContext context, MessageModel msg, bool isMe) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.elevatedColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                msg.isRead ? Icons.done_all : Icons.done,
                color: msg.isRead
                    ? AppColors.success
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              title: Text(
                msg.isRead ? l10n.read : l10n.sent,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                msg.isRead && msg.readAt != null
                    ? l10n.sentAndReadAt(
                        _formatDateTime(msg.createdAt),
                        _formatDateTime(msg.readAt!),
                      )
                    : l10n.sentAndReadAt(
                        _formatDateTime(msg.createdAt),
                        '...',
                      ),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ),
            if (isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  l10n.deleteMessage,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(context, msg.id, isMe);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(
      BuildContext context, String messageId, bool isMe) async {
    final cubit = context.read<MessagesCubit>();
    await cubit.deleteMessage(messageId, isSender: isMe);
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.messageDeleted),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocListener<MessagesCubit, MessagesState>(
      listener: (context, state) {
        if (state is MessagesChatLoaded) {
          _cachedOtherUserId = state.otherUserId;
          _cachedTripId = state.tripId;
        }
      },
      child: BlocBuilder<MessagesCubit, MessagesState>(
        builder: (context, state) {
          if (state is MessagesChatLoaded || state is MessagesSending) {
            final cubit = context.read<MessagesCubit>();
            return _ChatUI(
              state: state,
              l: l,
              scrollController: _scrollController,
              textController: _textController,
              onScrollToBottom: _scrollToBottom,
              onSendMessage: () =>
                  _sendMessage(context, _textController, cubit),
              onShowMessageOptions: (msg, isMe) =>
                  _showMessageOptions(context, msg, isMe),
            );
          }
          if (state is MessagesError) {
            return _buildError(context, l, state.message);
          }
          // Fallback to placeholder UI instead of full-screen loader
          final placeholderState = MessagesChatLoaded(
            messages: const [],
            otherName: widget.otherUserName ?? '',
            otherUserId: widget.otherUserId,
            tripId: widget.tripId,
            canSend: true,
          );
          
          return _ChatUI(
            state: placeholderState,
            l: l,
            scrollController: _scrollController,
            textController: _textController,
            onScrollToBottom: _scrollToBottom,
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l, String message) {
    return Scaffold(
      appBar: AppBar(backgroundColor: context.bgColor, elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 44, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<MessagesCubit>().loadConversations();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(l.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat UI
// ─────────────────────────────────────────────────────────────────────────────
class _ChatUI extends StatefulWidget {
  final MessagesState state;
  final AppLocalizations l;
  final ScrollController scrollController;
  final TextEditingController textController;
  final VoidCallback onScrollToBottom;
  final VoidCallback? onSendMessage;
  final void Function(MessageModel msg, bool isMe)? onShowMessageOptions;

  const _ChatUI({
    required this.state,
    required this.l,
    required this.scrollController,
    required this.textController,
    required this.onScrollToBottom,
    this.onSendMessage,
    this.onShowMessageOptions,
  });

  @override
  State<_ChatUI> createState() => _ChatUIState();
}

class _ChatUIState extends State<_ChatUI> {
  bool _showScrollToBottom = false;

  List<MessageModel> get _messages => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).messages
      : (widget.state as MessagesSending).currentMessages;

  bool get _canSend => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).canSend
      : false;

  String get _otherName => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).otherName
      : '';

  String? get _otherAvatarUrl => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).otherAvatarUrl
      : null;

  bool get _isOtherOnline => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).isOtherOnline
      : false;

  bool get _isOtherTyping => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).isOtherTyping
      : false;

  bool get _hasMore => widget.state is MessagesChatLoaded
      ? (widget.state as MessagesChatLoaded).hasMore
      : false;

  String _getCurrentUserId() => SupabaseService.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final show = widget.scrollController.hasClients &&
        widget.scrollController.offset > 250;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          if (_canSend) _buildTypingBanner(context),
          Expanded(child: _buildMessagesList(context)),
          if (_canSend) _buildInputBar(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: context.bgColor.withValues(alpha: 0.75),
          ),
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isDark ? Brightness.light : Brightness.dark,
      ),
      leadingWidth: 50,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          color: context.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _buildAvatar(context),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherName.isNotEmpty ? _otherName : widget.l.theChat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isOtherTyping
                      ? Row(
                          key: const ValueKey('typing'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _AnimatedTypingDots(),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.typing,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          key: const ValueKey('status'),
                          _isOtherOnline
                              ? AppLocalizations.of(context)!.online
                              : AppLocalizations.of(context)!.offline,
                          style: TextStyle(
                            color: _isOtherOnline
                                ? AppColors.success
                                : context.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            image: _otherAvatarUrl != null && _otherAvatarUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(_otherAvatarUrl!),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  )
                : null,
          ),
          child: _otherAvatarUrl == null || _otherAvatarUrl!.isEmpty
              ? const Icon(Icons.person_rounded,
                  size: 22, color: AppColors.primary)
              : null,
        ),
        if (_isOtherOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: context.elevatedColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypingBanner(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: _isOtherTyping
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: context.elevatedColor.withValues(alpha: 0.5),
              child: Row(
                children: [
                  const _AnimatedTypingDots(),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.typing,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMessagesList(BuildContext context) {
    final messages = _messages;

    if (messages.isEmpty) {
      if (_hasMore) {
        return const _ChatShimmerList();
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text(
              widget.l.startChat,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: widget.scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }

            final msg = messages[index];
            final isMe = msg.senderId == _getCurrentUserId();
            final showDate = _shouldShowDate(messages, index);

            // ✅ FIX: الأفاتار يظهر جنب أول رسالة في المجموعة من الأسفل (الأحدث)
            // في reverse list: index 0 = أسفل (أحدث) ← هنا المفروض الأفاتار
            // index - 1 = الرسالة اللي تحتها (أحدث منها)
            final showAvatar = !isMe && _shouldShowAvatar(messages, index);

            return Column(
              children: [
                if (showDate) _DateSeparator(date: msg.createdAt),
                const SizedBox(height: 4),
                _ChatBubble(
                  message: msg,
                  isMe: isMe,
                  showAvatar: showAvatar,
                  avatarUrl: _otherAvatarUrl,
                  onLongPress: widget.onShowMessageOptions != null
                      ? () => widget.onShowMessageOptions!(msg, isMe)
                      : null,
                ),
              ],
            );
          },
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          bottom: _showScrollToBottom ? 16 : -56,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton.small(
              onPressed: widget.onScrollToBottom,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  // ── date helpers ──────────────────────────────────────────────────────────

  bool _shouldShowDate(List<MessageModel> messages, int index) {
    // في reverse list: index+1 = الرسالة فوقها (أقدم)
    // نعرض الـ date separator لما اليوم يختلف عن الرسالة الأقدم فوقها
    if (index == messages.length - 1) return true;
    return !_isSameDay(
        messages[index].createdAt, messages[index + 1].createdAt);
  }

  // ✅ FIX الرئيسي: الأفاتار يظهر جنب الرسالة الأسفل (الأحدث) في كل مجموعة
  //
  // في reverse ListView:
  //   index 0   → أسفل الشاشة (الأحدث)   ← المفروض الأفاتار هنا
  //   index 1   → فوقها
  //   index 2   → فوقها
  //
  // نعرض الأفاتار لما الرسالة اللي تحتها (index-1) من مرسل مختلف أو مافيش رسالة تحت
  bool _shouldShowAvatar(List<MessageModel> messages, int index) {
    // أول رسالة في القائمة = الأحدث = أسفل الشاشة → دايمًا أفاتار
    if (index == 0) return true;
    final current = messages[index];
    // الرسالة اللي تحتها في الشاشة (أحدث = index أصغر)
    final below = messages[index - 1];
    // لو الرسالة اللي تحتها من مرسل تاني أو يوم تاني → أفاتار
    return current.senderId != below.senderId ||
        !_isSameDay(current.createdAt, below.createdAt);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(BuildContext context) {
    return Container(
      color: context.bgColor, // solid background for premium feel
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), // added bottom padding for SafeArea
      child: Directionality(
        textDirection: TextDirection.ltr, // Force LTR so send button is on the right
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Directionality(
                textDirection: Directionality.of(context), // Revert to app direction for text field
                child: Container(
                  decoration: BoxDecoration(
                    color: context.elevatedColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: context.divColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: widget.textController,
                          style: TextStyle(color: context.textPrimary, fontSize: 16),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => widget.onSendMessage?.call(),
                          maxLines: 5,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: widget.l.typeMessage,
                            hintStyle: TextStyle(color: context.textSecondary.withValues(alpha: 0.7), fontSize: 15),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                // The user specifically wanted the icon NOT to point in "the other direction".
                // We'll use the standard send icon which faces right towards the screen.
                icon: const Icon(Icons.send_rounded, size: 22),
                color: Colors.white,
                onPressed: widget.onSendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input icon button
// ─────────────────────────────────────────────────────────────────────────────
class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final BuildContext context;

  const _InputIconButton({
    required this.icon,
    required this.tooltip,
    required this.context,
    this.onTap,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      decoration: BoxDecoration(
        color: context.elevatedColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: AppColors.primary,
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated typing dots
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 550),
      ),
    );

    _scaleAnimations = _controllers
        .map(
          (c) => TweenSequence<double>([
            TweenSequenceItem(
                tween: Tween(begin: 1.0, end: 1.6)
                    .chain(CurveTween(curve: Curves.easeOut)),
                weight: 40),
            TweenSequenceItem(
                tween: Tween(begin: 1.6, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeIn)),
                weight: 60),
          ]).animate(c),
        )
        .toList();

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _scaleAnimations[i],
          builder: (_, __) => Transform.scale(
            scale: _scaleAnimations[i].value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                    alpha: 0.5 + 0.5 * _scaleAnimations[i].value - 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date separator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);

    final String label;
    if (msgDate == today) {
      label = AppLocalizations.of(context)!.today;
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      label = AppLocalizations.of(context)!.yesterday;
    } else if (now.difference(msgDate).inDays < 7) {
      final locale = Localizations.localeOf(context).languageCode;
      label = intl.DateFormat.EEEE(locale).format(msgDate);
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: context.elevatedColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.divColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat bubble
// ─────────────────────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final String? avatarUrl;
  final VoidCallback? onLongPress;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    this.showAvatar = false,
    this.avatarUrl,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsetsDirectional.only(
            bottom: 4,
            start: isMe ? 60 : 4,
            end: isMe ? 4 : 60,
            top: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showAvatar) _buildSmallAvatar(context),
              if (!isMe && !showAvatar) const SizedBox(width: 32),
              Flexible(
                child: Container(
                  padding: _getPadding(),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : context.elevatedColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 4 : 20),
                      bottomRight: Radius.circular(isMe ? 20 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _buildContent(context),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _buildTimeAndStatus(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallAvatar(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4, bottom: 2),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
            ? NetworkImage(avatarUrl!)
            : null,
        child: (avatarUrl == null || avatarUrl!.isEmpty)
            ? const Icon(Icons.person_rounded,
                size: 16, color: AppColors.primary)
            : null,
      ),
    );
  }

  EdgeInsets _getPadding() {
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildContent(BuildContext context) {

    return Text(
      message.content,
      style: TextStyle(
        color: isMe ? Colors.white : context.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildTimeAndStatus(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${message.createdAt.hour.toString().padLeft(2, '0')}:'
          '${message.createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 10,
            color: isMe ? Colors.white70 : context.textSecondary,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 16,
            color: message.isRead
                ? Colors.blue[300]
                : Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Chat Shimmer (WhatsApp Style)
// ─────────────────────────────────────────────────────────────────────────────
class _ChatShimmerList extends StatelessWidget {
  const _ChatShimmerList();

  @override
  Widget build(BuildContext context) {
    // A realistic sequence of dummy messages (from bottom/newest to top/oldest)
    final mockLayouts = [
      {"isMe": true, "lines": 1, "widthRatio": 0.4, "showAvatar": false},
      {"isMe": false, "lines": 2, "widthRatio": 0.6, "showAvatar": false},
      {"isMe": false, "lines": 1, "widthRatio": 0.3, "showAvatar": true},
      {"isMe": true, "lines": 3, "widthRatio": 0.75, "showAvatar": false},
      {"isMe": true, "lines": 1, "widthRatio": 0.2, "showAvatar": false},
      {"isMe": false, "lines": 2, "widthRatio": 0.5, "showAvatar": true},
      {"isMe": true, "lines": 1, "widthRatio": 0.3, "showAvatar": false},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: 20, // Enough to fill the tallest screens
      itemBuilder: (context, index) {
        final layout = mockLayouts[index % mockLayouts.length];
        final isMe = layout["isMe"] as bool;
        final showAvatar = layout["showAvatar"] as bool;
        final lines = layout["lines"] as int;
        final widthRatio = layout["widthRatio"] as double;

        return Align(
          alignment: isMe
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            margin: EdgeInsetsDirectional.only(
              bottom: 4,
              start: isMe ? 60 : 4,
              end: isMe ? 4 : 60,
              top: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe && showAvatar)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4, bottom: 2),
                    child: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (!isMe && !showAvatar) const SizedBox(width: 32),
                Flexible(
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      width: MediaQuery.of(context).size.width * widthRatio,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          lines,
                          (lineIndex) => Container(
                            height: 12,
                            margin: EdgeInsets.only(
                              bottom: lineIndex == lines - 1 ? 0 : 6,
                              right: lineIndex == lines - 1 && lines > 1 ? 40 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
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