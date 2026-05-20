import 'package:flutter/foundation.dart';

import '../../../../../services/supabase_service.dart';

class ChatbotRepository {
  Future<List<Map<String, dynamic>>> loadMessages() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await SupabaseService.client
          .from('support_messages')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(100);

      final messages =
          (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

      for (final msg in messages) {
        if (msg.containsKey('sender_role') && msg['sender_role'] != null) {
          msg['_isUser'] = msg['sender_role'] == 'user';
        } else {
          msg['_isUser'] = msg['sender_id'] == userId ||
              (msg['sender_id'] == null && msg['sender_role'] == 'user');
        }
      }
      return messages;
    } catch (e) {
      debugPrint('ChatbotRepository: loadMessages error: $e');
      return [];
    }
  }

  Future<void> saveUserMessage(String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client.from('support_messages').insert({
        'user_id': userId,
        'message': text,
        'sender_role': 'user',
      });
    } catch (e) {
      debugPrint('ChatbotRepository: saveUserMessage error: $e');
    }
  }

  Future<String?> fetchAiReply(String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;

    try {
      final history = await SupabaseService.client
          .from('support_messages')
          .select('message, sender_role')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content':
              'You are a helpful taxi app support assistant. Answer in the same language as the user.'
        },
      ];

      final historyList =
          (history as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (historyList.isNotEmpty) {
        for (final msg in historyList.reversed) {
          final role =
              (msg['sender_role'] as String?) == 'user' ? 'user' : 'assistant';
          final content = msg['message'] as String? ?? '';
          if (content.isNotEmpty) {
            messages.add({'role': role, 'content': content});
          }
        }
      }

      messages.add({'role': 'user', 'content': text});

      final response = await SupabaseService.client.functions.invoke(
        'chatbot-ai',
        body: {
          'messages': messages,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status == 200 &&
          response.data != null &&
          response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final directContent = data['content'] ?? data['reply'];
        if (directContent is String && directContent.trim().isNotEmpty) {
          return directContent.trim();
        }
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices[0];
          if (choice is Map) {
            final message = choice['message'];
            if (message is Map) {
              final content = message['content'] as String?;
              if (content != null && content.trim().isNotEmpty) {
                return content.trim();
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('ChatbotRepository: fetchAiReply error: $e');
      return null;
    }
  }

  Future<void> saveSupportReply(String reply) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client.from('support_messages').insert({
        'user_id': userId,
        'sender_id': null,
        'message': reply,
        'sender_role': 'support',
      });
    } catch (e) {
      debugPrint('ChatbotRepository: saveSupportReply error: $e');
    }
  }
}
