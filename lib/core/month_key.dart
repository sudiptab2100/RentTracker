import 'package:intl/intl.dart';

import 'app_config.dart';

/// Helpers for working with month identifiers in `yyyy-MM` form. Because the
/// format is zero-padded and fixed width, lexicographic comparison matches
/// chronological order.
class MonthKey {
  static final DateFormat _key = DateFormat('yyyy-MM');
  static final DateFormat _long = DateFormat('MMMM yyyy');
  static final DateFormat _short = DateFormat('MMM yyyy');

  static String of(DateTime d) => _key.format(DateTime(d.year, d.month));

  static String current() => of(DateTime.now());

  static DateTime parse(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String next(String key) {
    final d = parse(key);
    return of(DateTime(d.year, d.month + 1));
  }

  static String prev(String key) {
    final d = parse(key);
    return of(DateTime(d.year, d.month - 1));
  }

  static int compare(String a, String b) => a.compareTo(b);

  static bool isValid(String key) => RegExp(r'^\d{4}-\d{2}$').hasMatch(key);

  static String label(String key) => _long.format(parse(key));

  static String shortLabel(String key) => _short.format(parse(key));

  /// Inclusive list of month keys from [from] to [to]. Empty if [from] is after
  /// [to]. Capped by [AppConfig.maxGeneratedMonths] for safety.
  static List<String> range(String from, String to) {
    if (compare(from, to) > 0) return const [];
    final result = <String>[];
    var cur = from;
    while (compare(cur, to) <= 0) {
      result.add(cur);
      cur = next(cur);
      if (result.length > AppConfig.maxGeneratedMonths) break;
    }
    return result;
  }
}
