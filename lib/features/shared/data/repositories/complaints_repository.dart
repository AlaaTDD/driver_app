
import '../../../../services/supabase_service.dart';



class ComplaintsRepository {
  Future<void> submitComplaint({
    required String title,
    required String description,
    String? tripId,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw Exception('errorNotLoggedIn');
    await SupabaseService.client.from('complaints').insert({
      'user_id': user.id,
      if (tripId != null) 'trip_id': tripId,
      'title': title.trim(),
      'description': description.trim(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> myComplaintsStream() {
    final user = SupabaseService.currentUser;
    if (user == null) return Stream.value([]);
    
    return SupabaseService.client
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((data) => data.cast<Map<String, dynamic>>());
  }
}
