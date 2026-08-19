// Android/iOS values from Firebase project crimeatrip-41d24.
//
// Setup: tourism-platform/docs/push-notifications-fcm.md
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// True only for platforms that already have real Firebase options.
  static bool get configured {
    if (kIsWeb) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android.apiKey != 'REPLACE_ME';
      case TargetPlatform.iOS:
        return ios.apiKey != 'REPLACE_ME';
      default:
        return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web FCM is out of scope for CrimeaTrip mobile.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNdFA5WSqgM1xQt2pdUIS-hDRvoMGWJuE',
    appId: '1:254312974108:android:bd0ac3821923c58dab5cd9',
    messagingSenderId: '254312974108',
    projectId: 'crimeatrip-41d24',
    storageBucket: 'crimeatrip-41d24.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCG28sFNysO0vH1dVaCDw65VOkZt4mZMuA',
    appId: '1:254312974108:ios:83cc618193b078b6ab5cd9',
    messagingSenderId: '254312974108',
    projectId: 'crimeatrip-41d24',
    storageBucket: 'crimeatrip-41d24.firebasestorage.app',
    iosBundleId: 'com.crimeatravel.tourismMobile',
  );
}
