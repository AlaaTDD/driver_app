import 'dart:async';
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
      child: const _MessagesView(),
    );
  }
}

class _MessagesView extends StatefulWidget {
  const _MessagesView();

  @override
  State<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<_MessagesView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  Timer? _typingTimer;

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
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 500), () {
      context.read<MessagesCubit>().updateTyping(_textController.text.isNotEmpty);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocBuilder<MessagesCubit, MessagesState>(
      builder: (context, state) {
        if (state is MessagesChatLoaded || state is MessagesSending) {
          return _ChatUI(
            state: state,
            l: l,
            scrollController: _scrollController,
            textController: _textController,
            onScrollToBottom: _scrollToBottom,
          );
        }
        if (state is MessagesError) {
          return _buildError(context, l, state.message);
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );
      },
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
                child: const Icon(Icons.error_outline, size: 44, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
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

class _ChatUI extends StatelessWidget {
  final MessagesState state;
  final AppLocalizations l;
  final ScrollController scrollController;
  final TextEditingController textController;
  final VoidCallback onScrollToBottom;

  const _ChatUI({
    required this.state,
    required this.l,
    required this.scrollController,
    required this.textController,
    required this.onScrollToBottom,
  });

  List<MessageModel> get _messages =>
      state is MessagesChatLoaded
          ? (state as MessagesChatLoaded).messages
          : (state as MessagesSending).currentMessages;

  bool get _canSend =>
      state is MessagesChatLoaded ? (state as MessagesChatLoaded).canSend : false;

  String get _otherName =>
      state is MessagesChatLoaded ? (state as MessagesChatLoaded).otherName : '';

  String? get _otherAvatarUrl =>
      state is MessagesChatLoaded ? (state as MessagesChatLoaded).otherAvatarUrl : null;

  bool get _isOtherOnline =>
      state is MessagesChatLoaded ? (state as MessagesChatLoaded).isOtherOnline : false;

  bool get _isOtherTyping =>
      state is MessagesChatLoaded ? (state as MessagesChatLoaded).isOtherTyping : false;

  bool get _hasMore =>
      state is MessagesChatLoaded ? (state as MessagesChatLoaded).hasMore : false;

  String _getCurrentUserId() => SupabaseService.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          if (_canSend) _buildTypingIndicator(context),
          Expanded(
            child: _buildMessagesList(context),
          ),
          if (_canSend) _buildInputBar(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: context.elevatedColor,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      leadingWidth: 40,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: context.textPrimary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _buildAvatar(context),
          const SizedBox(width: 12),
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
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isOtherTyping
                      ? Row(
                          key: const ValueKey('typing'),
                          children: [
                            _buildTypingDots(),
                            const SizedBox(width: 6),
                            const Text(
                              'يكتب الآن...',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          key: const ValueKey('status'),
                          _isOtherOnline ? 'متصل الآن' : 'غير متصل',
                          style: TextStyle(
                            color: _isOtherOnline
                                ? AppColors.success
                                : context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
                  )
                : null,
          ),
          child: _otherAvatarUrl == null || _otherAvatarUrl!.isEmpty
              ? const Icon(Icons.person_rounded, size: 22, color: AppColors.primary)
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

  Widget _buildTypingDots() {
    return SizedBox(
      width: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: const AlwaysStoppedAnimation(0),
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    if (!_isOtherTyping) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: context.elevatedColor.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Text(
            'يكتب الآن...',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          _buildTypingDots(),
        ],
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context) {
    final messages = _messages;

    if (messages.isEmpty) {
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
              l.startChat,
              style: TextStyle(
                  color: context.textSecondary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final msg = messages[index];
            final isMe = msg.senderId == _getCurrentUserId();
            final showDate = _shouldShowDate(messages, index);
            final showAvatar = !isMe && _shouldShowAvatar(messages, index);
            return Column(
              children: [
                if (showDate) _DateSeparator(date: msg.createdAt),
                const SizedBox(height: 4),
                _ChatBubble(
                  message: msg,
                  isMe: isMe,
                  showAvatar: showAvatar,
                  onLongPress: () => _showMessageOptions(context, msg, isMe),
                ),
              ],
            );
          },
        ),
        if (_hasNewMessages())
          Positioned(
            bottom: 16,
            right: 0,
            left: 0,
            child: Center(
              child: FloatingActionButton.small(
                onPressed: onScrollToBottom,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowDate(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index].createdAt;
    final next = messages[index + 1].createdAt;
    return !_isSameDay(current, next);
  }

  bool _shouldShowAvatar(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index];
    final next = messages[index + 1];
    return current.senderId != next.senderId || _isSameDay(current.createdAt, next.createdAt) == false;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasNewMessages() {
    return false; // Can be enhanced to detect new messages while scrolled up
  }

  Widget _buildInputBar(BuildContext context) {
    final cubit = context.read<MessagesCubit>();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              color: AppColors.primary,
              onPressed: () => _pickAndSendImage(context, cubit),
              tooltip: 'إرسال صورة',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.divColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: textController,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(context, textController, cubit),
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: l.typeMessage,
                    hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.85),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
                onPressed: () => _sendMessage(context, textController, cubit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(BuildContext context, TextEditingController controller, MessagesCubit cubit) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final state = cubit.state;
    String? otherUserId;
    String? tripId;
    if (state is MessagesChatLoaded) {
      otherUserId = state.otherUserId;
      tripId = state.tripId;
    }
    cubit.sendMessage(text, otherUserId ?? '', tripId: tripId);
    controller.clear();
    cubit.updateTyping(false);
    HapticFeedback.lightImpact();
    onScrollToBottom();
  }

  Future<void> _pickAndSendImage(BuildContext context, MessagesCubit cubit) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    String? otherUserId;
    String? tripId;
    final state = cubit.state;
    if (state is MessagesChatLoaded) {
      otherUserId = state.otherUserId;
      tripId = state.tripId;
    }
    await cubit.sendImage(File(image.path), otherUserId ?? '', tripId: tripId);
    onScrollToBottom();
  }

  void _showMessageOptions(BuildContext context, MessageModel msg, bool isMe) {
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
                color: context.divColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                msg.isRead ? Icons.done_all : Icons.done,
                color: msg.isRead ? AppColors.success : context.textSecondary,
              ),
              title: Text(
                msg.isRead ? 'تم القراءة' : 'تم الإرسال',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                msg.isRead && msg.readAt != null
                    ? 'أُرسلت: ${_formatDateTime(msg.createdAt)}\nقُرئت: ${_formatDateTime(msg.readAt!)}'
                    : 'أُرسلت: ${_formatDateTime(msg.createdAt)}',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text(
                  'حذف الرسالة',
                  style: TextStyle(
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

  Future<void> _deleteMessage(BuildContext context, String messageId, bool isMe) async {
    final cubit = context.read<MessagesCubit>();
    await cubit.deleteMessage(messageId, isSender: isMe);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حذف الرسالة'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);

    String label;
    if (msgDate == today) {
      label = 'اليوم';
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      label = 'أمس';
    } else if (now.difference(msgDate).inDays < 7) {
      const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      label = days[msgDate.weekday - 1];
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Row(
      children: [
        Expanded(child: Divider(color: context.divColor.withValues(alpha: 0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.divColor.withValues(alpha: 0.4))),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onLongPress;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    this.showAvatar = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 4,
            left: isMe ? 60 : (showAvatar ? 4 : 40),
            right: isMe ? 4 : 60,
            top: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            textDirection: isMe ? TextDirection.rtl : TextDirection.ltr,
            children: [
              if (!isMe && showAvatar) _buildSmallAvatar(context),
              if (!isMe && !showAvatar) const SizedBox(width: 32),
              Flexible(
                child: Container(
                  padding: _getPadding(),
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
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      _buildContent(context),
                      const SizedBox(height: 4),
                      _buildTimeAndStatus(context),
                    ],
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
      padding: const EdgeInsets.only(right: 4, bottom: 2),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
      ),
    );
  }

  EdgeInsets _getPadding() {
    if (message.type == 'image') {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildContent(BuildContext context) {
    if (message.type == 'image' && message.attachmentUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          message.attachmentUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      );
    }
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
          '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 10,
            color: isMe ? Colors.white70 : context.textSecondary,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: message.isRead ? AppColors.success : Colors.white70,
          ),
        ],
      ],
    );
  }
}
