import 'dart:convert';
import '../../../../services/supabase_service.dart';
import '../../../../core/errors/exceptions.dart';

class ComplaintsRepository {
  // ─── Submit new complaint ──────────────────────────────────────────
  Future<String> submitComplaint({
    required String title,
    required String description,
    String? tripId,
    String category = 'general',
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw AuthException('errorNotLoggedIn');

    final response = await SupabaseService.client.from('complaints').insert({
      'user_id': user.id,
      if (tripId != null) 'trip_id': tripId,
      'title': title.trim(),
      'description': description.trim(),
      'status': 'pending',
      'category': category,
      'created_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    return response['id'] as String;
  }

  // ─── Get my complaints list (paginated) ───────────────────────────
  Future<List<Map<String, dynamic>>> getMyComplaintsPaged({
    required int page,
    required int pageSize,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return [];

    final from = page * pageSize;
    final to = from + pageSize - 1;

    final data = await SupabaseService.client
        .from('complaints')
        .select(
            'id, title, description, status, category, priority, created_at, admin_reply, admin_notes, replied_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false) // newest first
        .range(from, to);

    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Get my complaints list (all — kept for fallback) ─────────────
  Future<List<Map<String, dynamic>>> getMyComplaints() async {
    final user = SupabaseService.currentUser;
    if (user == null) return [];

    final data = await SupabaseService.client
        .from('complaints')
        .select(
            'id, title, description, status, category, priority, created_at, admin_reply, admin_notes, replied_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Get full complaint thread (merged, sorted) ────────────────────
  Future<List<Map<String, dynamic>>> getComplaintThread(
      String complaintId) async {
    final user = SupabaseService.currentUser;
    if (user == null) return [];

    final data = await SupabaseService.client
        .from('complaints')
        .select(
            'id, description, status, admin_reply, admin_notes, created_at, replied_at')
        .eq('id', complaintId)
        .eq('user_id', user.id)
        .single();

    final thread = <Map<String, dynamic>>[];

    // Original complaint message
    thread.add({
      'id': 'original',
      'sender_type': 'user',
      'message': data['description'],
      'created_at': data['created_at'],
      'is_original': true,
    });

    // Parse admin replies (stored in admin_reply as JSON array)
    final adminReplyRaw = data['admin_reply'];
    if (adminReplyRaw != null &&
        adminReplyRaw.toString().trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(adminReplyRaw) as List;
        for (final msg in parsed) {
          thread.add({
            ...Map<String, dynamic>.from(msg as Map),
            'sender_type': 'admin',
          });
        }
      } catch (_) {
        // Legacy plain-text fallback
        thread.add({
          'id': 'legacy-admin',
          'sender_type': 'admin',
          'message': adminReplyRaw,
          'created_at': data['replied_at'] ?? data['created_at'],
        });
      }
    }

    // Parse user follow-up replies (stored in admin_notes as JSON array)
    final userNotesRaw = data['admin_notes'];
    if (userNotesRaw != null && userNotesRaw.toString().trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(userNotesRaw) as List;
        for (final msg in parsed) {
          thread.add({
            ...Map<String, dynamic>.from(msg as Map),
            'sender_type': 'user',
          });
        }
      } catch (e) {
        // ignore parse error - admin_notes might not be valid JSON
      }
    }

    // Sort all by created_at
    thread.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final bTime =
          DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return aTime.compareTo(bTime);
    });

    return thread;
  }

  // ─── Send user reply (via Supabase RPC with SECURITY DEFINER) ─────
  Future<void> submitUserReply({
    required String complaintId,
    required String message,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw AuthException('errorNotLoggedIn');

    try {
      await SupabaseService.client.rpc('add_complaint_user_reply', params: {
        'p_complaint_id': complaintId,
        'p_user_id': user.id,
        'p_message': message.trim(),
      });
    } catch (e) {
      throw Exception('فشل في إرسال الرد: $e');
    }
  }

  // ─── Close complaint (user initiated via RPC) ──────────────────────
  Future<void> closeComplaint(String complaintId) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw AuthException('errorNotLoggedIn');

    try {
      await SupabaseService.client.rpc('close_complaint_by_user', params: {
        'p_complaint_id': complaintId,
        'p_user_id': user.id,
      });
    } catch (e) {
      throw Exception('فشل في إغلاق الشكوى: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  /// Returns true if last message in thread is from admin (user needs to see it)
  bool hasUnreadAdminReply(Map<String, dynamic> complaint) {
    final adminReply = complaint['admin_reply'];
    if (adminReply == null || adminReply.toString().trim().isEmpty) {
      return false;
    }
    try {
      final parsed = jsonDecode(adminReply) as List;
      if (parsed.isEmpty) return false;

      // Get all messages
      final allMsgs = [...parsed];
      final userNotesRaw = complaint['admin_notes'];
      if (userNotesRaw != null && userNotesRaw.toString().trim().isNotEmpty) {
        try {
          final userParsed = jsonDecode(userNotesRaw) as List;
          allMsgs.addAll(userParsed);
        } catch (_) {}
      }

      if (allMsgs.isEmpty) return false;

      // Sort by created_at and check last
      allMsgs.sort((a, b) {
        final aTime = DateTime.tryParse((a as Map)['created_at'] ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse((b as Map)['created_at'] ?? '') ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });

      final lastMsg = allMsgs.last as Map;
      return lastMsg['sender_type'] == 'admin';
    } catch (_) {
      return adminReply.toString().trim().isNotEmpty;
    }
  }

  /// Returns a short preview of the last message
  String getLastMessagePreview(Map<String, dynamic> complaint) {
    try {
      final adminReply = complaint['admin_reply'];
      final userNotes = complaint['admin_notes'];

      final msgs = <Map<String, dynamic>>[];

      if (adminReply != null && adminReply.toString().trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(adminReply) as List;
          msgs.addAll(parsed.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }

      if (userNotes != null && userNotes.toString().trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(userNotes) as List;
          msgs.addAll(parsed.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }

      if (msgs.isEmpty) return complaint['description'] ?? '';

      msgs.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });

      return msgs.last['message'] ?? complaint['description'] ?? '';
    } catch (_) {
      return complaint['description'] ?? '';
    }
  }
}
