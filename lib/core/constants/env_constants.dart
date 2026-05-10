
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConstants {
  
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

  
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_KEY']!;

  // R2 secrets removed for security (now handled in Edge Function)

}
