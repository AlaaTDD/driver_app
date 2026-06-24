import 'package:snapix/core/services/user_presence_service.dart';
import 'package:snapix/core/services/cell_subscription_service.dart';
import 'package:snapix/core/services/heatmap_service.dart';
import 'package:snapix/core/services/location_service.dart';
import 'package:snapix/core/services/directions_service.dart';
import 'package:snapix/core/services/fcm_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class LogoutCoordinator {
  static final LogoutCoordinator instance = LogoutCoordinator._();
  LogoutCoordinator._();

  final List<Future<void> Function()> _cleanupCallbacks = [];

  void register(Future<void> Function() cleanup) {
    if (!_cleanupCallbacks.contains(cleanup)) {
      _cleanupCallbacks.add(cleanup);
    }
  }

  Future<void> performLogout() async {
    await Future.wait([
      UserPresenceService.instance.stopBroadcasting().catchError((e) {
        AppLogger.warning('LogoutCoordinator: presence cleanup failed — $e');
      }),
      CellSubscriptionService.instance.dispose().catchError((e) {
        AppLogger.warning('LogoutCoordinator: cell cleanup failed — $e');
      }),
      FCMService().clearFcmToken().catchError((e) {
        AppLogger.warning('LogoutCoordinator: FCM cleanup failed — $e');
      }),
    ]);

    HeatmapService.instance.dispose();
    LocationService.instance.stopAllTracking();
    DirectionsService.clearCache();

    await Future.wait(
      _cleanupCallbacks.map((fn) => fn().catchError((e) {
            AppLogger.warning('LogoutCoordinator: cleanup failed — $e');
          })),
    );
    _cleanupCallbacks.clear();
    AppLogger.info('LogoutCoordinator: all services cleaned up');
  }
}
