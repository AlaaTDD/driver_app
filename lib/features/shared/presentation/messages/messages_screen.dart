// lib/features/shared/presentation/messages/messages_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../services/supabase_service.dart';
import 'data/messages_repository.dart';

class MessagesScreen extends StatefulWidget {
  final String? tripId;

  const MessagesScreen({super.key, this.tripId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  /// Trip chat uses MessageModel, support chat uses raw maps.
  /// We store a unified list of _ChatDisplayItem for rendering.
  List<_ChatDisplayItem> _displayMessages = [];
  bool _isLoading = true;
  String? _error;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _realtimeSubscription;
  final _repository = MessagesRepository();

  bool get _isTripChat => widget.tripId != null && widget.tripId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    if (_isTripChat) _subscribeToRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (_isTripChat) {
        final messages = await _repository.loadTripMessages(widget.tripId!);
        setState(() {
          _displayMessages = messages.map((m) => _ChatDisplayItem(
            text: m.content,
            isMe: m.senderId == currentUserId,
            createdAt: m.createdAt,
          )).toList();
          _isLoading = false;
        });
      } else {
        final data = await _repository.loadSupportMessages();
        setState(() {
          _displayMessages = data.map((m) => _ChatDisplayItem(
            text: m['message'] as String? ?? '',
            // FIX: Use DB sender_role to distinguish user vs support messages
            isMe: (m['sender_role'] as String? ?? 'user') == 'user',
            createdAt: m['created_at'] != null
                ? DateTime.parse(m['created_at'] as String)
                : DateTime.now(),
          )).toList();
          _isLoading = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context)!.failedLoadMessages;
        _isLoading = false;
      });
    }
  }

  void _subscribeToRealtime() {
    _realtimeSubscription?.cancel();
    final currentUserId = SupabaseService.currentUser?.id;
    _realtimeSubscription = _repository
        .subscribeToTripMessages(widget.tripId!)
        .listen((messages) {
      if (!mounted) return;
      setState(() {
        _displayMessages = messages.map((m) => _ChatDisplayItem(
          text: m.content,
          isMe: m.senderId == currentUserId,
          createdAt: m.createdAt,
        )).toList();
      });
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      if (_isTripChat) {
        final l = AppLocalizations.of(context)!;
        final senderName = await _repository.fetchCurrentUserName() ?? l.newMessage;
        if (!mounted) return;
        await _repository.sendTripMessageWithNotification(
          tripId: widget.tripId!,
          text: text,
          senderName: senderName,
          newMessageFrom: (name) => l.newMessageFrom(name),
        );
      } else {
        await _repository.sendSupportMessage(text);
        _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedSendMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currentUserId = SupabaseService.currentUser?.id;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(_isTripChat ? AppLocalizations.of(context)!.theChat : l.messages),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!,
                                style: TextStyle(color: context.textPrimary)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadMessages,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              child: Text(l.retry),
                            ),
                          ],
                        ),
                      )
                    : _displayMessages.isEmpty
                        ? Center(
                            child: Text(
                              _isTripChat ? AppLocalizations.of(context)!.startChat : l.helpAndSupport,
                              style: TextStyle(
                                  color: context.textSecondary, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _displayMessages.length,
                            itemBuilder: (context, index) {
                              final msg = _displayMessages[index];
                              return _ChatBubble(
                                message: msg.text,
                                time: _formatTime(msg.createdAt),
                                isMe: msg.isMe,
                              );
                            },
                          ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        border: Border(
          top: BorderSide(color: context.textSecondary.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: context.textPrimary),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.typeMessage,
                  hintStyle: TextStyle(color: context.textSecondary),
                  filled: true,
                  fillColor: context.bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: AppColors.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMe;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : context.elevatedColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : context.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isMe ? Colors.white70 : context.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight display item unifying trip messages (MessageModel)
/// and support messages (raw maps) into a single renderable type.
class _ChatDisplayItem {
  final String text;
  final bool isMe;
  final DateTime? createdAt;

  const _ChatDisplayItem({
    required this.text,
    required this.isMe,
    this.createdAt,
  });
}
