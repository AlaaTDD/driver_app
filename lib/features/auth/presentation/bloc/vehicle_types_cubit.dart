import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/supabase_service.dart';

// [AUTH-28 FIX] Extend Equatable to prevent unnecessary BlocBuilder rebuilds
class VehicleTypesState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> vehicleTypes;
  final String? error;

  const VehicleTypesState({
    this.isLoading = false,
    this.vehicleTypes = const [],
    this.error,
  });

  @override
  List<Object?> get props => [isLoading, vehicleTypes, error];

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
          .order('sort_order', ascending: true)
          .timeout(const Duration(seconds: 15));

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
