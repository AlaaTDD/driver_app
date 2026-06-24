// [APP-C-01 COMPLETE] Migrated from flutter_dotenv → --dart-define-from-file.
// Firebase Web / Windows keys are injected at compile time via dart_defines.json.
// Android / iOS / macOS use native config files (google-services.json / GoogleService-Info.plist).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  // [APP-C-02] Web Firebase app: 1:741233752146:web:33dc1f9bbf59ae6268878b
  // Keys come from dart_defines.json → FIREBASE_WEB_* entries.
  static FirebaseOptions get web {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    assert(
      apiKey.isNotEmpty,
      '\n\n[APP-C-02] FIREBASE_WEB_API_KEY is missing!\n'
      'Add it to dart_defines.json under FIREBASE_WEB_API_KEY.\n',
    );
    if (apiKey.isEmpty) {
      throw StateError(
        '[APP-C-02] FIREBASE_WEB_API_KEY is not configured. '
        'Add it to dart_defines.json — see firebase_options.dart.',
      );
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      measurementId: String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID'),
    );
  }

  static FirebaseOptions get android => throw UnsupportedError(
        'Use google-services.json for Android native initialization.',
      );

  static FirebaseOptions get ios => throw UnsupportedError(
        'Use GoogleService-Info.plist for iOS native initialization.',
      );

  static FirebaseOptions get macos => throw UnsupportedError(
        'Use GoogleService-Info.plist for macOS native initialization.',
      );

  // [APP-C-02] Windows Firebase app: 1:741233752146:web:74b47ca31701645368878b
  // Keys come from dart_defines.json → FIREBASE_WINDOWS_* entries.
  static FirebaseOptions get windows {
    const apiKey = String.fromEnvironment('FIREBASE_WINDOWS_API_KEY');
    if (apiKey.isEmpty) {
      throw StateError(
        '[APP-C-02] FIREBASE_WINDOWS_API_KEY is not configured. '
        'Add it to dart_defines.json — see firebase_options.dart.',
      );
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: String.fromEnvironment('FIREBASE_WINDOWS_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      measurementId: String.fromEnvironment('FIREBASE_WINDOWS_MEASUREMENT_ID'),
    );
  }
}
