
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../trips/data/models/trip_model.dart';
import 'driver_trips_event.dart';
import 'driver_trips_state.dart';

class DriverTripsBloc extends Bloc<DriverTripsEvent, DriverTripsState> {
  DriverTripsBloc() : super(DriverTripsInitial()) {
    on<LoadDriverTrips>(_onLoadDriverTrips);
  }

  Future<void> _onLoadDriverTrips(
    LoadDriverTrips event,
    Emitter<DriverTripsState> emit,
  ) async {
    emit(DriverTripsLoading());
    try {
      final driverId = SupabaseService.currentUser?.id;
      if (driverId == null) {
        emit(const DriverTripsLoaded([]));
        return;
      }
      final data = await SupabaseService.client
          .from('trips')
          .select('*, user:users!trips_user_id_fkey(id, name, avatar_url, phone)')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      
      final trips = (data as List)
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
      emit(DriverTripsLoaded(trips));
    } catch (e, stackTrace) {
      debugPrint('❌ DriverTripsBloc: Load failed: $e');
      debugPrint(stackTrace.toString());
      emit(const DriverTripsError('errorLoadTrips'));
    }
  }
}
