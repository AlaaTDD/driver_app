import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConstants {
  static String _required(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('$key not configured');
    }
    return value;
  }

  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');

  static String get googleMapsApiKey => _required('GOOGLE_MAPS_KEY');

  // R2 secrets removed for security (now handled in Edge Function)
}
