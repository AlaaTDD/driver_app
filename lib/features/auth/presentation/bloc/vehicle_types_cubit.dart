import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/supabase_service.dart';

class VehicleTypesState {
  final bool isLoading;
  final List<Map<String, dynamic>> vehicleTypes;
  final String? error;

  const VehicleTypesState({
    this.isLoading = false,
    this.vehicleTypes = const [],
    this.error,
  });

  VehicleTypesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? vehicleTypes,
    String? error,
  }) {
    return VehicleTypesState(
      isLoading: isLoading ?? this.isLoading,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      error: error,
    );
  }
}

class VehicleTypesCubit extends Cubit<VehicleTypesState> {
  VehicleTypesCubit() : super(const VehicleTypesState());

  Future<void> fetchVehicleTypes() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final rows = await SupabaseService.client
          .from('vehicle_types')
          .select('name, display_name')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      emit(state.copyWith(
        isLoading: false,
        vehicleTypes: List<Map<String, dynamic>>.from(rows),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
