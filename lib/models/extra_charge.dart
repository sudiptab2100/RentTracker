import '../core/firestore_utils.dart';

/// An arbitrary additional charge on a monthly rent record (e.g. maintenance,
/// water, repairs).
class ExtraCharge {
  final String label;

  /// Amount in integer minor units (paise).
  final int amount;

  const ExtraCharge({required this.label, required this.amount});

  Map<String, dynamic> toMap() => {
        'label': label,
        'amount': amount,
      };

  factory ExtraCharge.fromMap(Map<String, dynamic> map) => ExtraCharge(
        label: (map['label'] ?? '') as String,
        amount: asInt(map['amount']),
      );
}
