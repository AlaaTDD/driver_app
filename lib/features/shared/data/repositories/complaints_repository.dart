import 'dart:convert';
import 'package:snapix/core/models/complaint_message_model.dart';
import 'package:snapix/core/models/complaint_model.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/errors/exceptions.dart';
import 'package:snapix/core/utils/app_logger.dart';

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

    final response = await SupabaseService.client
        .from('complaints')
        .insert({
          'user_id': user.id,
          if (tripId != null) 'trip_id': tripId,
          'title': title.trim(),
          'description': description.trim(),
          'status': 'pending',
          'category': category,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  // ─── Get my complaints list (paginated) ───────────────────────────
  Future<List<ComplaintModel>> getMyComplaintsPaged({
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
        .order('created_at', ascending: false)
        .range(from, to);

    return (data as List)
        .whereType<Map>()
        .map((e) => ComplaintModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ─── Get my complaints list (all — kept for fallback) ─────────────
  Future<List<ComplaintModel>> getMyComplaints() async {
    final user = SupabaseService.currentUser;
    if (user == null) return [];

    final data = await SupabaseService.client
        .from('complaints')
        .select(
            'id, title, description, status, category, priority, created_at, admin_reply, admin_notes, replied_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (data as List)
        .whereType<Map>()
        .map((e) => ComplaintModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ─── Get full complaint thread (merged, sorted) ────────────────────
  Future<List<ComplaintMessageModel>> getComplaintThread(
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

    final thread = <ComplaintMessageModel>[];

    // Original complaint message
    thread.add(ComplaintMessageModel(
      id: 'original',
      senderType: 'user',
      message: data['description'] as String? ?? '',
      createdAt: _date(data['created_at']),
      isOriginal: true,
    ));

    // Admin replies (stored in admin_reply as JSON array)
    final adminReplyRaw = data['admin_reply'];
    if (adminReplyRaw != null && adminReplyRaw.toString().trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(adminReplyRaw) as List;
        for (final msg in parsed) {
          final msgMap = Map<String, dynamic>.from(msg as Map);
          thread.add(ComplaintMessageModel.fromJson({
            ...msgMap,
            'sender_type': 'admin',
          }));
        }
      } catch (e, st) {
        AppLogger.warning(
            'ComplaintsRepository: admin_reply JSON parse failed: $e');
        AppLogger.debug(st.toString());
        thread.add(ComplaintMessageModel(
          id: 'legacy-admin',
          senderType: 'admin',
          message: adminReplyRaw.toString(),
          createdAt: _date(data['replied_at'] ?? data['created_at']),
        ));
      }
    }

    // User follow-up replies (stored in admin_notes as JSON array)
    final userNotesRaw = data['admin_notes'];
    if (userNotesRaw != null && userNotesRaw.toString().trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(userNotesRaw) as List;
        for (final msg in parsed) {
          final msgMap = Map<String, dynamic>.from(msg as Map);
          thread.add(ComplaintMessageModel.fromJson({
            ...msgMap,
            'sender_type': 'user',
          }));
        }
      } catch (e, st) {
        AppLogger.warning(
            'ComplaintsRepository: admin_notes JSON parse failed: $e');
        AppLogger.debug(st.toString());
        thread.add(ComplaintMessageModel(
          id: 'legacy-user-notes',
          senderType: 'user',
          message: userNotesRaw.toString(),
          createdAt: _date(data['replied_at'] ?? data['created_at']),
        ));
      }
    }

    // Sort all messages chronologically
    thread.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
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

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Returns true if the last message in the thread is from admin
  /// (meaning the user hasn't yet seen/responded to it).
  bool hasUnreadAdminReply(ComplaintModel complaint) {
    final adminReply = complaint.adminReply;
    if (adminReply == null || adminReply.trim().isEmpty) return false;

    try {
      final parsed = jsonDecode(adminReply) as List;
      if (parsed.isEmpty) return false;

      // Merge admin messages + user follow-up notes into one list
      final allMsgs = <Map<String, dynamic>>[
        ...parsed.map((e) => Map<String, dynamic>.from(e as Map)),
      ];

      final userNotesRaw = complaint.adminNotes;
      if (userNotesRaw != null && userNotesRaw.trim().isNotEmpty) {
        try {
          final userParsed = jsonDecode(userNotesRaw) as List;
          allMsgs.addAll(
              userParsed.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (e, st) {
          AppLogger.debug(
              '⚠️ ComplaintsRepository: unread admin_notes parse failed: $e');
          AppLogger.debug(st.toString());
          allMsgs.add(<String, dynamic>{
            'sender_type': 'user',
            'created_at': complaint.repliedAt?.toIso8601String() ??
                complaint.createdAt?.toIso8601String(),
          });
        }
      }

      if (allMsgs.isEmpty) return false;

      allMsgs.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] as String? ?? '') ??
            DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at'] as String? ?? '') ??
            DateTime(2000);
        return aTime.compareTo(bTime);
      });

      return allMsgs.last['sender_type'] == 'admin';
    } catch (e, st) {
      AppLogger.warning(
          'ComplaintsRepository: unread admin_reply parse failed: $e');
      AppLogger.debug(st.toString());
      return adminReply.trim().isNotEmpty;
    }
  }

  /// Returns a short preview of the last message in the thread.
  String getLastMessagePreview(ComplaintModel complaint) {
    try {
      final msgs = <Map<String, dynamic>>[];

      final adminReply = complaint.adminReply;
      if (adminReply != null && adminReply.trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(adminReply) as List;
          msgs.addAll(
              parsed.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (e, st) {
          AppLogger.debug(
              '⚠️ ComplaintsRepository: preview admin_reply parse failed: $e');
          AppLogger.debug(st.toString());
          msgs.add(<String, dynamic>{
            'message': adminReply,
            'created_at': complaint.repliedAt?.toIso8601String() ??
                complaint.createdAt?.toIso8601String(),
          });
        }
      }

      final userNotes = complaint.adminNotes;
      if (userNotes != null && userNotes.trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(userNotes) as List;
          msgs.addAll(
              parsed.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (e, st) {
          AppLogger.debug(
              '⚠️ ComplaintsRepository: preview admin_notes parse failed: $e');
          AppLogger.debug(st.toString());
          msgs.add(<String, dynamic>{
            'message': userNotes,
            'created_at': complaint.repliedAt?.toIso8601String() ??
                complaint.createdAt?.toIso8601String(),
          });
        }
      }

      if (msgs.isEmpty) return complaint.description;

      msgs.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] as String? ?? '') ??
            DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at'] as String? ?? '') ??
            DateTime(2000);
        return aTime.compareTo(bTime);
      });

      return (msgs.last['message'] as String?) ?? complaint.description;
    } catch (e, st) {
      AppLogger.warning('ComplaintsRepository: preview build failed: $e');
      AppLogger.debug(st.toString());
      return complaint.description;
    }
  }
}
