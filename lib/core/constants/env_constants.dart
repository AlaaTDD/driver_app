// [APP-C-01 FIXED] Secrets are now injected at build-time via --dart-define.
// Build command:
//   flutter build apk \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJ... \
//     --dart-define=GOOGLE_MAPS_KEY=AIza...
//
// For local development create a build script or use launch.json with args.
// Never add .env back to pubspec assets — keys would be readable inside the APK.

class EnvConstants {
  static String _required(String key, String compiledValue) {
    if (compiledValue.isEmpty) {
      throw StateError(
        '$key is not configured. '
        'Pass --dart-define=$key=<value> when building.',
      );
    }
    return compiledValue;
  }

  static String get supabaseUrl => _required(
        'SUPABASE_URL',
        const String.fromEnvironment('SUPABASE_URL'),
      );

  static String get supabaseAnonKey => _required(
        'SUPABASE_ANON_KEY',
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  static String get googleMapsApiKey => _required(
        'GOOGLE_MAPS_KEY',
        const String.fromEnvironment('GOOGLE_MAPS_KEY'),
      );

  // R2 secrets are handled server-side in Edge Functions — never expose here.
}
