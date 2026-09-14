import '../core/firestore_utils.dart';

/// A single payment made by the tenant toward a monthly rent record. Stored as
/// an element of the `payments` array so dates are kept as ISO strings (which
/// also makes master export/import lossless).
class Payment {
  final String id;

  /// Amount paid in integer minor units (paise).
  final int amount;
  final DateTime date;
  final String note;

  const Payment({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: (map['id'] ?? '') as String,
        amount: asInt(map['amount']),
        date: tsToDate(map['date']),
        note: (map['note'] ?? '') as String,
      );
}
