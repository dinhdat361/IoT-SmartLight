// File manually generated based on google-services.json
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FirebaseOptions not configured for iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'FirebaseOptions not configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FirebaseOptions not configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions not configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'Unknown platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGBHG738hSNbLgYxUu7QrS69YnRa9XxlE',
    appId: '1:627239957572:android:4a34b99dd70e05365f3811',
    messagingSenderId: '627239957572',
    projectId: 'smart-home-v2-3199a',
    databaseURL:
        'https://smart-home-v2-3199a-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'smart-home-v2-3199a.firebasestorage.app',
  );
}
