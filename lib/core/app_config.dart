/// App-wide static configuration.
class AppConfig {
  static const String appName = 'RentTracker';

  /// Currency display settings (INR).
  static const String currencySymbol = '\u20B9'; // ₹
  static const String currencyLocale = 'en_IN';

  /// Web OAuth 2.0 client ID from the Firebase console, required for Google
  /// Sign-In on Android when not using google-services.json. Fill this in after
  /// creating your Firebase project (see SETUP.md). Leave empty to disable
  /// Google Sign-In gracefully.
  static const String googleServerClientId = '';

  static bool get hasGoogleConfig => googleServerClientId.isNotEmpty;

  /// Safety cap used when lazily generating monthly rent records.
  static const int maxGeneratedMonths = 240;
}
