import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Default [FirebaseOptions] for all platforms.
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyCfaw8I-rwXu8j0El340yIGr-N2agTzp6c',
    appId: 'YOUR_APP_ID', // TODO: replace with your actual app ID
    messagingSenderId: 'YOUR_SENDER_ID', // TODO: replace with your sender ID
    projectId: 'crystalgrimoire-production',
    authDomain: 'crystalgrimoire-production.firebaseapp.com',
    storageBucket: 'crystalgrimoire-production.appspot.com',
    measurementId: 'YOUR_MEASUREMENT_ID', // TODO: replace with your measurement ID
  );
}
