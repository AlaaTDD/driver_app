
import '../../../../services/supabase_service.dart';



class ComplaintsRepository {
  Future<void> submitComplaint({
    required String title,
    required String description,
    String? tripId,
  }) async {
    final user = SupabaseService.currentUser;
    await SupabaseService.client.from('complaints').insert({
      'user_id': user?.id,
      if (tripId != null) 'trip_id': tripId,
      'title': title.trim(),
      'description': description.trim(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
