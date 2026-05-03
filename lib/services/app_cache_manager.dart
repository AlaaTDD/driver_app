
import 'package:flutter_cache_manager/flutter_cache_manager.dart';




class AppCacheManager {
  static const key = 'taxi_app_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );
}
