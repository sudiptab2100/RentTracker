/// A phone number split into a dial-in country code and a local number.
/// Stored in Firestore as `{ countryCode: "+91", number: "9876543210" }`.
class PhoneNumber {
  final String countryCode; // e.g. "+91"
  final String number; // local digits only, e.g. "9876543210"

  const PhoneNumber({this.countryCode = '+91', this.number = ''});

  static const PhoneNumber empty = PhoneNumber();

  bool get isEmpty => number.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Digits only with country code, e.g. `919876543210` (for wa.me).
  String get e164Digits => '$countryCode$number'.replaceAll(RegExp(r'[^0-9]'), '');

  /// E.164 form, e.g. `+919876543210` (for tel: links). Empty if no number.
  String get e164 => isEmpty ? '' : '+$e164Digits';

  /// Human display, e.g. `+91 9876543210`.
  String get display => isEmpty ? '' : '$countryCode $number';

  Map<String, dynamic> toMap() => {'countryCode': countryCode, 'number': number};

  factory PhoneNumber.fromMap(Map<String, dynamic> map) => PhoneNumber(
        countryCode: (map['countryCode'] ?? '+91') as String,
        number: (map['number'] ?? '') as String,
      );

  /// Parses a legacy free-form string (possibly containing a country code)
  /// into parts, keeping the last 10 digits as the local number (default +91).
  factory PhoneNumber.fromLegacy(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const PhoneNumber();
    if (digits.length <= 10) return PhoneNumber(number: digits);
    final number = digits.substring(digits.length - 10);
    final cc = '+${digits.substring(0, digits.length - 10)}';
    return PhoneNumber(countryCode: cc, number: number);
  }

  /// Reads either the new map form or a legacy string from a Firestore value.
  factory PhoneNumber.fromField(dynamic value) {
    if (value is Map) return PhoneNumber.fromMap(Map<String, dynamic>.from(value));
    if (value is String && value.isNotEmpty) return PhoneNumber.fromLegacy(value);
    return const PhoneNumber();
  }

  PhoneNumber copyWith({String? countryCode, String? number}) => PhoneNumber(
        countryCode: countryCode ?? this.countryCode,
        number: number ?? this.number,
      );
}

/// Safely coerces `map[newKey]` (new form) or `map[legacyKey]` (old string)
/// into a [PhoneNumber].
PhoneNumber readPhone(Map<String, dynamic> map, String newKey, String legacyKey) =>
    PhoneNumber.fromField(map[newKey] ?? map[legacyKey]);

/// A country dial code with a display name.
class CountryCode {
  final String dial; // e.g. "+91"
  final String name; // e.g. "India"
  const CountryCode(this.dial, this.name);
}

/// Curated list of common country dial codes (India first / default).
const List<CountryCode> kCountryCodes = [
  CountryCode('+91', 'India'),
  CountryCode('+1', 'USA / Canada'),
  CountryCode('+44', 'United Kingdom'),
  CountryCode('+971', 'UAE'),
  CountryCode('+966', 'Saudi Arabia'),
  CountryCode('+974', 'Qatar'),
  CountryCode('+965', 'Kuwait'),
  CountryCode('+968', 'Oman'),
  CountryCode('+973', 'Bahrain'),
  CountryCode('+65', 'Singapore'),
  CountryCode('+60', 'Malaysia'),
  CountryCode('+61', 'Australia'),
  CountryCode('+64', 'New Zealand'),
  CountryCode('+880', 'Bangladesh'),
  CountryCode('+977', 'Nepal'),
  CountryCode('+94', 'Sri Lanka'),
  CountryCode('+92', 'Pakistan'),
  CountryCode('+49', 'Germany'),
  CountryCode('+33', 'France'),
  CountryCode('+39', 'Italy'),
  CountryCode('+34', 'Spain'),
  CountryCode('+81', 'Japan'),
  CountryCode('+86', 'China'),
  CountryCode('+27', 'South Africa'),
  CountryCode('+254', 'Kenya'),
  CountryCode('+234', 'Nigeria'),
];
