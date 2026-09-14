/// Simple, dependency-free form validators.
class Validators {
  static String? required(String? v, [String name = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final ok = RegExp(r'^\+?[0-9\s\-]{7,15}$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid phone number (with country code)';
  }
}
