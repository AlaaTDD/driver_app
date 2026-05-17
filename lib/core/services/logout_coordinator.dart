import 'package:flutter/foundation.dart';
import 'package:snapix/services/user_presence_service.dart';
import 'package:snapix/services/cell_subscription_service.dart';
import 'package:snapix/services/heatmap_service.dart';
import 'package:snapix/services/location_service.dart';
import 'package:snapix/services/directions_service.dart';
import 'package:snapix/services/fcm_service.dart';

class LogoutCoordinator {
  static final LogoutCoordinator instance = LogoutCoordinator._();
  LogoutCoordinator._();

  final List<Future<void> Function()> _cleanupCallbacks = [];

  void register(Future<void> Function() cleanup) {
    _cleanupCallbacks.add(cleanup);
  }

  Future<void> performLogout() async {
    await Future.wait(
      _cleanupCallbacks.map((fn) => fn().catchError((e) {
        debugPrint('⚠️ LogoutCoordinator: cleanup failed — $e');
      })),
    );
    _cleanupCallbacks.clear();
    debugPrint('✅ LogoutCoordinator: all services cleaned up');
  }
}
