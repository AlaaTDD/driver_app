// lib/features/user/presentation/profile/bloc/profile_bloc.dart
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
      final data = await SupabaseService.client
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();
      emit(ProfileLoaded(Map<String, dynamic>.from(data)));
    } catch (e, stackTrace) {
      debugPrint('❌ ProfileBloc: Load failed: $e');
      debugPrint(stackTrace.toString());
      emit(const ProfileError('errorLoadProfile'));
    }
  }

  // FIX S05: Whitelist of fields that users are allowed to update on themselves
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
      // FIX S05: Only allow whitelisted fields — reject arbitrary keys like is_admin
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
