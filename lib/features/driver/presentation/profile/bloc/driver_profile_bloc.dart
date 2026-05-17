import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import 'package:snapix/features/driver/data/repositories/driver_profile_repository.dart';
import 'driver_profile_event.dart';
import 'driver_profile_state.dart';

class DriverProfileBloc extends Bloc<DriverProfileEvent, DriverProfileState> {
  final DriverProfileRepository _repository = DriverProfileRepository();

  DriverProfileBloc() : super(DriverProfileInitial()) {
    on<LoadDriverProfile>(_onLoadDriverProfile);
    on<UpdateDriverProfile>(_onUpdateDriverProfile);
  }

  Future<void> _onLoadDriverProfile(
    LoadDriverProfile event,
    Emitter<DriverProfileState> emit,
  ) async {
    emit(DriverProfileLoading());
    try {
      final driverId = SupabaseService.currentUser?.id;
      if (driverId == null) {
        emit(const DriverProfileError('errorNotLoggedIn'));
        return;
      }

      final profile = await _repository.loadDriverProfile(driverId);
      if (profile == null) {
        emit(const DriverProfileError('errorLoadProfile'));
        return;
      }
      emit(DriverProfileLoaded(profile));
    } catch (e, stackTrace) {
      debugPrint('❌ DriverProfileBloc: Load failed: $e');
      debugPrint(stackTrace.toString());
      emit(const DriverProfileError('errorLoadProfile'));
    }
  }

  Future<void> _onUpdateDriverProfile(
    UpdateDriverProfile event,
    Emitter<DriverProfileState> emit,
  ) async {
    try {
      final driverId = SupabaseService.currentUser?.id;
      if (driverId == null) return;

      final profile =
          await _repository.updateDriverProfile(driverId, event.data);
      if (profile != null) {
        emit(DriverProfileLoaded(profile));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ DriverProfileBloc: Update failed: $e');
      debugPrint(stackTrace.toString());
      emit(const DriverProfileError('errorUpdateProfile'));
    }
  }
}
