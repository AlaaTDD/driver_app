
import 'dart:convert';
import 'package:http/http.dart' as http;
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
        .order('created_at', ascending: true);

    final messages = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

    
    
    bool nextIsUser = true;
    for (final msg in messages) {
      
      if (msg.containsKey('sender_role') && msg['sender_role'] != null) {
        msg['_isUser'] = msg['sender_role'] == 'user';
      } else {
        msg['_isUser'] = nextIsUser;
        nextIsUser = !nextIsUser;
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
    final response = await http.post(
      Uri.parse(EnvConstants.aiApiUrl),
      headers: {
        'Authorization': 'Bearer ${EnvConstants.openRouterApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': EnvConstants.aiModel,
        'messages': [
          {'role': 'system', 'content': 'You are a helpful taxi app support assistant. Answer in the same language as the user.'},
          {'role': 'user', 'content': text},
        ],
        'max_tokens': EnvConstants.aiMaxTokens,
        'temperature': EnvConstants.aiTemperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data['choices']?[0]?['message']?['content']?.toString().trim() ?? '';
      return reply.isNotEmpty ? reply : null;
    }
    return null;
  }

  
  
  Future<void> saveSupportReply(String reply) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('support_messages').insert({
      'user_id': userId,
      'message': reply,
      'sender_role': 'support',
    });
  }
}
