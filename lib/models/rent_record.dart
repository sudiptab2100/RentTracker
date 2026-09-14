import '../core/firestore_utils.dart';
import 'extra_charge.dart';
import 'payment.dart';

/// A monthly rent ledger entry for an apartment. The document id is the month
/// key (`yyyy-MM`). Amounts are integer minor units (paise).
///
/// Derived money:
///   totalDue = rentAmount + electricBill + Σ extraCharges + carryForward
///   paidAmount = Σ payments
///   balance = totalDue − paidAmount   (> 0 means outstanding)
class RentRecord {
  /// Month key, e.g. `2026-09`. Same as the document id.
  final String month;
  final int rentAmount;
  final int electricBill;
  final List<ExtraCharge> extraCharges;
  final List<Payment> payments;

  /// Outstanding balance brought forward from the previous month.
  final int carryForward;
  final DateTime createdAt;

  const RentRecord({
    required this.month,
    this.rentAmount = 0,
    this.electricBill = 0,
    this.extraCharges = const [],
    this.payments = const [],
    this.carryForward = 0,
    required this.createdAt,
  });

  String get id => month;

  int get extraTotal => extraCharges.fold(0, (sum, c) => sum + c.amount);

  int get paidAmount => payments.fold(0, (sum, p) => sum + p.amount);

  int get totalDue => rentAmount + electricBill + extraTotal + carryForward;

  /// Positive when the tenant still owes money; zero or negative when settled.
  int get balance => totalDue - paidAmount;

  int get outstanding => balance > 0 ? balance : 0;

  int get advance => balance < 0 ? -balance : 0;

  bool get isSettled => balance <= 0;

  factory RentRecord.fromMap(String id, Map<String, dynamic> map) => RentRecord(
        month: (map['month'] ?? id) as String,
        rentAmount: asInt(map['rentAmount']),
        electricBill: asInt(map['electricBill']),
        extraCharges: ((map['extraCharges'] ?? const []) as List)
            .map((e) => ExtraCharge.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        payments: ((map['payments'] ?? const []) as List)
            .map((e) => Payment.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        carryForward: asInt(map['carryForward']),
        createdAt: tsToDate(map['createdAt']),
      );

  Map<String, dynamic> _fields() => {
        'month': month,
        'rentAmount': rentAmount,
        'electricBill': electricBill,
        'extraCharges': extraCharges.map((e) => e.toMap()).toList(),
        'payments': payments.map((e) => e.toMap()).toList(),
        'carryForward': carryForward,
      };

  Map<String, dynamic> toMap() => {
        ..._fields(),
        'createdAt': dateToTs(createdAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        ..._fields(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory RentRecord.fromJson(Map<String, dynamic> json) => RentRecord.fromMap(
        (json['id'] ?? json['month'] ?? '') as String,
        json,
      );

  RentRecord copyWith({
    int? rentAmount,
    int? electricBill,
    List<ExtraCharge>? extraCharges,
    List<Payment>? payments,
    int? carryForward,
  }) =>
      RentRecord(
        month: month,
        rentAmount: rentAmount ?? this.rentAmount,
        electricBill: electricBill ?? this.electricBill,
        extraCharges: extraCharges ?? this.extraCharges,
        payments: payments ?? this.payments,
        carryForward: carryForward ?? this.carryForward,
        createdAt: createdAt,
      );
}
