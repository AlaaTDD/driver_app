
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConstants {
  
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

  
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_KEY']!;

  
  static String get r2AccountId => dotenv.env['R2_ACCOUNT_ID']!;
  static String get r2AccessKeyId => dotenv.env['R2_ACCESS_KEY_ID']!;
  static String get r2SecretKey => dotenv.env['R2_SECRET_KEY']!;
  static String get r2BucketName => dotenv.env['R2_BUCKET_NAME']!;
  static String get r2PublicUrl => dotenv.env['R2_PUBLIC_URL']!;

  
  static String get openRouterApiKey => dotenv.env['OPENAI_API_KEY']!;
  static String get aiApiUrl => dotenv.env['AI_API_URL']!;
  static String get aiModel => dotenv.env['AI_MODEL']!;
  static int get aiMaxTokens => int.parse(dotenv.env['AI_MAX_TOKENS']!);
  static double get aiTemperature => double.parse(dotenv.env['AI_TEMPERATURE']!);
}
