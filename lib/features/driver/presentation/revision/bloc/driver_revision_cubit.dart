import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/supabase_service.dart';
import '../../../data/repositories/driver_revision_repository.dart';
import 'driver_revision_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverRevisionCubit extends Cubit<DriverRevisionState> {
  StreamSubscription? _subscription;

  DriverRevisionCubit() : super(const DriverRevisionInitial());

  void subscribe() {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) {
      emit(const DriverRevisionError('errorNotLoggedIn'));
      return;
    }

    emit(const DriverRevisionLoading());
    _subscription?.cancel();
    // [المرحلة ج، البند 13] اشتراك موحّد بدلاً من استعلام مكرَّر —
    // انظر watchDriverRevisionRequests في driver_revision_repository.dart.
    _subscription = watchDriverRevisionRequests(driverId).listen(
      (requests) => emit(DriverRevisionLoaded(requests: requests)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.debug(
          'DriverRevisionCubit: subscription failed: $error\n$stackTrace',
        );
        emit(const DriverRevisionError('errorUnexpected'));
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
