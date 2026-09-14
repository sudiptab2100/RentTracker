import 'package:intl/intl.dart';

import 'app_config.dart';

/// Utilities for handling money as integer minor units (paise) to avoid
/// floating-point rounding errors. All amounts across the app are stored as
/// `int` paise and only converted to a double for display/formatting.
class Money {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: '${AppConfig.currencySymbol}\u00A0',
    decimalDigits: 2,
  );

  static final NumberFormat _plain = NumberFormat('#,##0.00', AppConfig.currencyLocale);

  /// Formats integer minor units as a currency string, e.g. `₹ 1,234.56`.
  static String format(int minor) => _currency.format(minor / 100);

  /// Formats without the currency symbol, e.g. `1,234.56`.
  static String formatPlain(int minor) => _plain.format(minor / 100);

  /// Parses a user-entered string of major units (rupees) into integer paise.
  /// Tolerates grouping separators and stray symbols.
  static int parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return 0;
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }

  /// Renders minor units back into an editable major-unit string (no grouping).
  static String toEditString(int minor) {
    if (minor % 100 == 0) return (minor ~/ 100).toString();
    return (minor / 100).toStringAsFixed(2);
  }
}
