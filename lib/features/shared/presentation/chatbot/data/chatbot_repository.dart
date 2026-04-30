// lib/features/shared/presentation/chatbot/data/chatbot_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../../services/supabase_service.dart';
import '../../../../../core/constants/env_constants.dart';

/// Repository that encapsulates all Supabase and AI API calls for the chatbot.
/// This separates UI from data sources (Clean Architecture).
///
/// SCHEMA NOTE: The `support_messages` table columns:
///   id (uuid), user_id (uuid), message (text), created_at (timestamptz),
///   sender_role (text CHECK IN ('user', 'support'))
/// sender_role distinguishes user messages from support/AI replies.
class ChatbotRepository {
  /// Load previous support messages.
  /// Uses `sender_role` column (added to schema) to distinguish user/support messages.
  /// Falls back to alternating heuristic only if sender_role is missing in legacy rows.
  Future<List<Map<String, dynamic>>> loadMessages() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseService.client
        .from('support_messages')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    final messages = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

    // Heuristic tagging: Messages alternate user/support.
    // First message is always from user.
    bool nextIsUser = true;
    for (final msg in messages) {
      // If sender_role column exists (future migration), use it.
      if (msg.containsKey('sender_role') && msg['sender_role'] != null) {
        msg['_isUser'] = msg['sender_role'] == 'user';
      } else {
        msg['_isUser'] = nextIsUser;
        nextIsUser = !nextIsUser;
      }
    }
    return messages;
  }

  /// Save a user message to the database.
  /// Only inserts columns that exist in the schema: user_id, message.
  Future<void> saveUserMessage(String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('support_messages').insert({
      'user_id': userId,
      'message': text,
      'sender_role': 'user',
    });
  }

  /// Calls OpenRouter AI API and returns the reply text.
  /// Returns null if the API fails or returns an empty reply.
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

  /// Save AI/support reply to the database.
  /// Only inserts columns that exist in the schema.
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
