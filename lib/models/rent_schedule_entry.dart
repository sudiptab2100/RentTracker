import '../core/firestore_utils.dart';

/// An effective-dated rent amount. Rent changes are recorded as new entries
/// so that historical months always use the amount that applied at the time.
class RentScheduleEntry {
  /// Month key (`yyyy-MM`) from which this amount takes effect.
  final String effectiveFrom;

  /// Rent amount in integer minor units (paise).
  final int amount;

  const RentScheduleEntry({required this.effectiveFrom, required this.amount});

  Map<String, dynamic> toMap() => {
        'effectiveFrom': effectiveFrom,
        'amount': amount,
      };

  factory RentScheduleEntry.fromMap(Map<String, dynamic> map) => RentScheduleEntry(
        effectiveFrom: (map['effectiveFrom'] ?? '') as String,
        amount: asInt(map['amount']),
      );
}
