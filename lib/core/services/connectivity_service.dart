import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:snapix/core/utils/app_logger.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get statusStream => _controller.stream;

  NetworkStatus _lastStatus = NetworkStatus.online;
  NetworkStatus get lastStatus => _lastStatus;

  StreamSubscription? _subscription;

  Future<void> init() async {
    _subscription?.cancel();

    // Set initial status
    _lastStatus =
        (await isOnline()) ? NetworkStatus.online : NetworkStatus.offline;
    _controller.add(_lastStatus);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      final status = isOnline ? NetworkStatus.online : NetworkStatus.offline;
      if (status != _lastStatus) {
        _lastStatus = status;
        _controller.add(status);
        if (kDebugMode) {
          AppLogger.debug('ConnectivityService: ${status.name}');
        }
      }
    });
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
