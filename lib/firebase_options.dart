// File is a placeholder until you run `flutterfire configure` (see SETUP.md).
//
// The app detects the placeholder values below and shows a friendly setup
// screen instead of crashing. Running `flutterfire configure` will overwrite
// this file with the real options for your Firebase project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Default [FirebaseOptions] for use with Firebase on this app.
class DefaultFirebaseOptions {
  static const String _placeholderApiKey = 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE';

  /// True while this file still contains placeholder values.
  static bool get isPlaceholder => android.apiKey == _placeholderApiKey;

  /// This is an Android-only application.
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfzf88SoD8fGagRphLa2OqIt-V1aCbtho',
    appId: '1:268504006821:android:fae4149a60ccc988ad0d4c',
    messagingSenderId: '268504006821',
    projectId: 'renttracker-vicky',
    storageBucket: 'renttracker-vicky.firebasestorage.app',
  );
}
