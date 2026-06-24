import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthHelper {
  static Future<String?> loginUser(WidgetTester tester, String email, String password) async {
    // Attempt DB login directly to bypass complex UI interactions without keys
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user?.id;
  }

  static Future<String?> getDriverIdByEmail(String email) async {
    final response = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('email', email)
        .single();
    return response['id'] as String?;
  }
}
