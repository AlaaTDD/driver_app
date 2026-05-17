
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(ProfileInitial()) {
    on<LoadUserProfile>(_onLoadUserProfile);
    on<UpdateProfile>(_onUpdateProfile);
  }

  Future<void> _onLoadUserProfile(
    LoadUserProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        emit(const ProfileError('errorNotLoggedIn'));
        return;
      }
      // Fix #20: fetch user_trip_stats in parallel
      final results = await Future.wait([
        SupabaseService.client
            .from('users')
            .select('*')
            .eq('id', userId)
            .single(),
        SupabaseService.client
            .from('user_trip_stats')
            .select('total_trips, completed_trips, cancelled_trips, total_km, avg_rating')
            .eq('user_id', userId)
            .maybeSingle()
            .catchError((_) => null),
      ]);

      final user = Map<String, dynamic>.from(results[0] as Map);
      final stats = results[1] as Map<String, dynamic>?;
      if (stats != null) {
        user['stats_total_trips']     = stats['total_trips'];
        user['stats_completed_trips'] = stats['completed_trips'];
        user['stats_cancelled_trips'] = stats['cancelled_trips'];
        user['stats_total_km']        = stats['total_km'];
        user['stats_avg_rating']      = stats['avg_rating'];
      }

      emit(ProfileLoaded(user));
    } catch (e, stackTrace) {
      debugPrint('❌ ProfileBloc: Load failed: $e');
      debugPrint(stackTrace.toString());
      emit(const ProfileError('errorLoadProfile'));
    }
  }

  
  static const Set<String> _allowedProfileFields = {
    'name', 'phone', 'avatar_url',
  };

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      
      final updateData = <String, dynamic>{};
      event.data.forEach((key, value) {
        if (_allowedProfileFields.contains(key)) {
          updateData[key] = value;
        }
      });
      if (updateData.isEmpty) {
        emit(const ProfileError('errorNoValidDataToUpdate'));
        return;
      }
      updateData['updated_at'] = DateTime.now().toIso8601String();
      final updated = await SupabaseService.client
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();
      emit(ProfileLoaded(Map<String, dynamic>.from(updated)));
    } catch (e, stackTrace) {
      debugPrint('❌ ProfileBloc: Update failed: $e');
      debugPrint(stackTrace.toString());
      emit(const ProfileError('errorUpdateProfile'));
    }
  }
}
