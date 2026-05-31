import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // [APP-C-02 FIXED] Validates required keys at startup — fails loudly, not silently.
  // To get FIREBASE_WEB_API_KEY:
  //   1. https://console.firebase.google.com → project arai-449ca
  //   2. Project Settings → General → Your apps
  //   3. Find Web app (ID: 1:741233752146:web:33dc1f9bbf59ae6268878b)
  //   4. Copy apiKey → paste into taxi_app/.env as FIREBASE_WEB_API_KEY=
  static FirebaseOptions get web {
    final apiKey = dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
    assert(
      apiKey.isNotEmpty,
      '\n\n[APP-C-02] FIREBASE_WEB_API_KEY is empty in .env!\n'
      'FCM push notifications will fail silently on Web/Windows.\n'
      'Get it from: Firebase Console → arai-449ca → Project Settings → Web app\n',
    );
    if (apiKey.isEmpty) {
      // In release mode, assert is disabled — throw explicitly so crash reports catch it
      throw StateError(
        '[APP-C-02] FIREBASE_WEB_API_KEY is not configured. '
        'Set it in taxi_app/.env — see firebase_options.dart for instructions.',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: dotenv.env['FIREBASE_WEB_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
      measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'] ?? '',
    );
  }

  static FirebaseOptions get android => throw UnsupportedError(
        'Use google-services.json for Android native initialization instead of hardcoded options.',
      );

  static FirebaseOptions get ios => throw UnsupportedError(
        'Use GoogleService-Info.plist for iOS native initialization instead of hardcoded options.',
      );

  static FirebaseOptions get macos => throw UnsupportedError(
        'Use GoogleService-Info.plist for macOS native initialization instead of hardcoded options.',
      );

  // [APP-C-02 FIXED] Windows also needs its own API key.
  // Get it from: Firebase Console → arai-449ca → Project Settings
  //   → Windows app (ID: 1:741233752146:web:74b47ca31701645368878b) → apiKey
  static FirebaseOptions get windows {
    final apiKey = dotenv.env['FIREBASE_WINDOWS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw StateError(
        '[APP-C-02] FIREBASE_WINDOWS_API_KEY is not configured. '
        'Set it in taxi_app/.env — see firebase_options.dart for instructions.',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: dotenv.env['FIREBASE_WINDOWS_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
      measurementId: dotenv.env['FIREBASE_WINDOWS_MEASUREMENT_ID'] ?? '',
    );
  }
}
