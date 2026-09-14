# RentTracker — Firebase setup

RentTracker needs **your own Firebase project** for authentication and the
Cloud Firestore database. The app ships with a placeholder `firebase_options.dart`
and shows a setup screen until you complete the steps below.

## 1. Prerequisites
- Flutter SDK (stable) and the Android toolchain (`flutter doctor` should pass).
- A Google account.

## 2. Create the Firebase project
1. Go to <https://console.firebase.google.com> and **Add project**.
2. In **Build → Authentication → Sign-in method**, enable:
   - **Email/Password**
   - **Google**
   - **Phone**
3. In **Build → Firestore Database**, click **Create database** (production mode,
   pick a region).

## 3. Wire the app to Firebase (FlutterFire)
Install the CLIs once:
```bash
npm install -g firebase-tools           # or: curl -sL https://firebase.tools | bash
dart pub global activate flutterfire_cli
firebase login
```
Then, from the project root:
```bash
flutterfire configure
```
Select your project and the **Android** platform. This overwrites
`lib/firebase_options.dart` with your real project keys (the app will now skip
the setup screen).

## 4. Google Sign-In configuration
Google Sign-In on Android needs a SHA-1/SHA-256 fingerprint and a Web client ID.
1. Get your debug SHA-1:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Copy the **SHA1** (and SHA-256) from the `debug` variant.
2. In **Firebase console → Project settings → Your apps → Android app**, add the
   fingerprints.
3. In **Project settings → General**, or the Google Cloud console
   (**APIs & Services → Credentials**), copy the **Web client (OAuth 2.0) ID**.
4. Paste it into `lib/core/app_config.dart`:
   ```dart
   static const String googleServerClientId = 'XXXXXX\u2011web.apps.googleusercontent.com';
   ```
   (If you leave it empty, Google Sign-In is disabled gracefully; email and phone
   still work.)

## 5. Phone authentication
- Phone OTP requires a real device/SIM to receive the SMS (emulators can use test
  numbers configured in the Firebase console).
- Make sure the SHA-1/SHA-256 fingerprints from step 4 are added, and that the
  Android app is registered.

## 6. Deploy Firestore security rules
The repo includes owner-scoped rules in `firestore.rules`:
```bash
firebase deploy --only firestore:rules
```
These restrict every document under `users/{uid}` to the authenticated owner.

## 7. Run
```bash
flutter run                 # debug
flutter build apk --release # release APK
```

## Notes
- **WhatsApp**: the app uses `wa.me` deep links and the OS share sheet. It cannot
  silently attach a PDF (that needs the paid WhatsApp Business API), so the owner
  taps *send* in WhatsApp after picking it from the share sheet.
- **Offline**: Firestore offline persistence is enabled, so the app keeps working
  with a flaky connection and syncs when back online.
- **Migration**: use **Settings → Data export & import → Master export (JSON)** to
  back up everything, and **Master import** to restore into any Firebase project
  (point `flutterfire configure` at the new project first).
