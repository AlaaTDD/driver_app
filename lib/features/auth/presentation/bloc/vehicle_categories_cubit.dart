import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/supabase_service.dart';

// [AUTH-28 FIX] Extend Equatable to prevent unnecessary BlocBuilder rebuilds
//
// [CATEGORY-FIX] كان الاسم القديم VehicleTypesCubit/VehicleTypesState وكان بيجيب
// من جدول service_tiers (باقات تسعير مثل economy/comfort/premium) بالغلط.
// هذا كان خلطًا مفاهيميًا بين "فئة المركبة" (vehicle_categories: car/suv/bike/van)
// و"باقة التسعير" (service_tiers). الآن بيجيب من جدول vehicle_categories
// مباشرة وهو المصدر الصحيح للفئة اللي تتخزّن في drivers_profile.vehicle_category.
class VehicleCategoriesState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> categories;
  final String? error;

  const VehicleCategoriesState({
    this.isLoading = false,
    this.categories = const [],
    this.error,
  });

  @override
  List<Object?> get props => [isLoading, categories, error];

  VehicleCategoriesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? categories,
    String? error,
  }) {
    return VehicleCategoriesState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      error: error,
    );
  }
}

class VehicleCategoriesCubit extends Cubit<VehicleCategoriesState> {
  VehicleCategoriesCubit() : super(const VehicleCategoriesState());

  Future<void> fetchVehicleCategories() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final rows = await SupabaseService.client
          .from('vehicle_categories')
          .select('id, name, display_name, icon, sort_order')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .timeout(const Duration(seconds: 15));

      emit(state.copyWith(
        isLoading: false,
        categories: List<Map<String, dynamic>>.from(rows),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
