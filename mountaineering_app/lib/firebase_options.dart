import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs',
    appId: '1:537544685736:android:940be2594fb947a28b2a9d',
    messagingSenderId: '537544685736',
    projectId: 'rotaplus-cd84d',
    storageBucket: 'rotaplus-cd84d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC3OlL045tj3uii1Jv7HO2MomZ4tGqWZaQ',
    appId: '1:537544685736:ios:bcc399280e5de21c8b2a9d',
    messagingSenderId: '537544685736',
    projectId: 'rotaplus-cd84d',
    storageBucket: 'rotaplus-cd84d.firebasestorage.app',
    iosClientId: '537544685736-6gi7ef78t1nba6n2hmj0hq2e5efbk0h8.apps.googleusercontent.com',
    iosBundleId: 'com.rotaplus.emniyetteyim',
  );
}
