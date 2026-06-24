import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/models/revision_request_model.dart';
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
    _subscription = SupabaseService.client
        .from('driver_revision_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .listen(
          (rows) => emit(
            DriverRevisionLoaded(
              requests:
                  rows.map((row) => RevisionRequestModel.fromJson(row)).toList(),
            ),
          ),
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
