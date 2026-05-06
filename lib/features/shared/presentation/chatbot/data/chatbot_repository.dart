
import '../../../../../services/supabase_service.dart';
import '../../../../../core/constants/env_constants.dart';








class ChatbotRepository {
  
  
  
  Future<List<Map<String, dynamic>>> loadMessages() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseService.client
        .from('support_messages')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .limit(100);

    final messages = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

    for (final msg in messages) {
      if (msg.containsKey('sender_role') && msg['sender_role'] != null) {
        msg['_isUser'] = msg['sender_role'] == 'user';
      } else {
        msg['_isUser'] = msg['sender_id'] == userId ||
            (msg['sender_id'] == null && msg['sender_role'] == 'user');
      }
    }
    return messages;
  }

  
  
  Future<void> saveUserMessage(String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('support_messages').insert({
      'user_id': userId,
      'message': text,
      'sender_role': 'user',
    });
  }

  
  
  Future<String?> fetchAiReply(String text) async {
    // Build conversation history from last messages in DB
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    final history = await SupabaseService.client
        .from('support_messages')
        .select('message, sender_role')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(10);

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': 'You are a helpful taxi app support assistant. Answer in the same language as the user.'
      },
    ];

    // Add history in chronological order
    if (history.isNotEmpty) {
      for (final msg in history.reversed) {
        final role = msg['sender_role'] == 'user' ? 'user' : 'assistant';
        messages.add({'role': role, 'content': msg['message'] as String});
      }
    }

    // Add current user message
    messages.add({'role': 'user', 'content': text});

    try {
      final response = await SupabaseService.client.functions.invoke('chatbot-ai', body: {
        'model': EnvConstants.aiModel,
        'messages': messages,
        'max_tokens': EnvConstants.aiMaxTokens,
        'temperature': EnvConstants.aiTemperature,
      });

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final reply = data['choices']?[0]?['message']?['content']?.toString().trim() ?? '';
        return reply.isNotEmpty ? reply : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  
  
  Future<void> saveSupportReply(String reply) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('support_messages').insert({
      'user_id': userId,
      'sender_id': null, // AI / system reply — not from the user
      'message': reply,
      'sender_role': 'support',
    });
  }
}
