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
    apiKey: _placeholderApiKey,
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
  );
}
