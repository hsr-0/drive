import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbc0WkBM46odXzxAHLjZjN4ePIC4vTCI4',
    appId: '1:266994090766:android:7fc6f7c4449bd346894d5f',
    messagingSenderId: '266994090766',
    projectId: 'beytei-me',
    databaseURL: 'https://beytei-me-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'beytei-me.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD7cRZeGlqv1LqeCNfkeQUiasGmg8aStj4',
    appId: '1:266994090766:ios:93b4e1702b37dc65894d5f',
    messagingSenderId: '266994090766',
    projectId: 'beytei-me',
    databaseURL: 'https://beytei-me-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'beytei-me.firebasestorage.app',
    androidClientId: '266994090766-ai3vunlb92gi4uvql9g1ti9p6lfm7366.apps.googleusercontent.com',
    iosClientId: '266994090766-aqbjrt1nfrfo0c13a6hfopi398v7t0de.apps.googleusercontent.com',
    iosBundleId: 'co.beytei.ios.taxi',
  );

}