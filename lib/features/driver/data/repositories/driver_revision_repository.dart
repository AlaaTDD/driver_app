import '../../../../core/models/revision_request_model.dart';
import '../../../../core/services/supabase_service.dart';

/// اشتراك Realtime موحّد على `driver_revision_requests` لسائق معيّن.
/// يجلب الآن أيضاً `field_statuses`, `reviewed_by`, `updated_at` الجديدة.
Stream<List<RevisionRequestModel>> watchDriverRevisionRequests(
  String driverId,
) {
  return SupabaseService.client
      .from('driver_revision_requests')
      .stream(primaryKey: ['id'])
      .eq('driver_id', driverId)
      .order('created_at', ascending: false)
      .map((rows) =>
          rows.map((row) => RevisionRequestModel.fromJson(row)).toList());
}
