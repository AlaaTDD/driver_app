// lib/services/app_cache_manager.dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// FIX H05: Previously, `get instance` created a new CacheManager on every
/// access, re-parsing the Config each time. Now uses a static final field
/// initialized once — true singleton pattern.
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
