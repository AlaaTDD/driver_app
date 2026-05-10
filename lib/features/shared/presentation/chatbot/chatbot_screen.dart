
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import 'package:snapix/features/shared/data/repositories/chatbot_repository.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  final _repository = ChatbotRepository();
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _repository.loadMessages();
      setState(() {
        for (final row in data) {
          _messages.add(ChatMessage(
            text: row['message'] as String? ?? '',
            isUser: row['_isUser'] as bool? ?? true,
          ));
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) { debugPrint('❌ ChatbotScreen loadMessages: $e');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    if (_lastSentAt != null && DateTime.now().difference(_lastSentAt!) < const Duration(seconds: 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorRateLimit)),
      );
      return;
    }
    _lastSentAt = DateTime.now();
    _controller.clear();
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    await _repository.saveUserMessage(text);

    
    final reply = await _repository.fetchAiReply(text);

    if (!mounted) return;
    final effectiveReply = reply ?? AppLocalizations.of(context)!.supportReply;
    await _repository.saveSupportReply(effectiveReply);

    setState(() {
      _messages.add(ChatMessage(text: effectiveReply, isUser: false));
      _isSending = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(AppLocalizations.of(context)!.supportAssistant),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.support_agent, color: AppColors.primary, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.welcomeSupport,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.howCanHelp,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _messages[index],
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: context.elevatedColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: context.textPrimary),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.typeMessage,
                      hintStyle: TextStyle(color: context.textSecondary),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: AppColors.primary),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : context.elevatedColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : context.textPrimary,
          ),
        ),
      ),
    );
  }
}
