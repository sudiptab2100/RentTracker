import '../core/firestore_utils.dart';
import 'extra_charge.dart';
import 'payment.dart';

/// A monthly rent ledger entry for an apartment. The document id is the month
/// key (`yyyy-MM`). Amounts are integer minor units (paise); meter readings are
/// integer units.
///
/// Electricity is metered: `electricBill = max(0, currUnits - prevUnits) * unitPrice`.
/// Month-level money:
///   monthCharges = rentAmount + electricBill + Σ extraCharges
///   paidAmount   = Σ payments
///   balance      = monthCharges − paidAmount   (this month only)
/// Cross-month carry-forward is handled by the running ledger, not stored here.
class RentRecord {
  final String month;
  final int rentAmount;

  /// Previous meter reading (units).
  final int prevUnits;

  /// Current meter reading (units).
  final int currUnits;

  /// Snapshot of the building's electricity price (paise/unit) at entry time.
  final int unitPrice;

  final List<ExtraCharge> extraCharges;
  final List<Payment> payments;

  /// Retained for import compatibility; superseded by the running ledger.
  final int carryForward;

  /// Legacy stored electricity amount (used only when no meter data exists).
  final int legacyElectricBill;

  final DateTime createdAt;

  const RentRecord({
    required this.month,
    this.rentAmount = 0,
    this.prevUnits = 0,
    this.currUnits = 0,
    this.unitPrice = 0,
    this.extraCharges = const [],
    this.payments = const [],
    this.carryForward = 0,
    this.legacyElectricBill = 0,
    required this.createdAt,
  });

  String get id => month;

  /// Units consumed this month (never negative).
  int get unitsUsed {
    final u = currUnits - prevUnits;
    return u > 0 ? u : 0;
  }

  /// Electricity amount (paise): computed from meter readings, or the legacy
  /// stored value for old records that predate metering.
  int get electricBill {
    final computed = unitsUsed * unitPrice;
    if (computed == 0 && prevUnits == 0 && currUnits == 0 && legacyElectricBill > 0) {
      return legacyElectricBill;
    }
    return computed;
  }

  bool get hasMeterReadings => prevUnits != 0 || currUnits != 0 || unitPrice != 0;

  int get extraTotal => extraCharges.fold(0, (sum, c) => sum + c.amount);

  int get paidAmount => payments.fold(0, (sum, p) => sum + p.amount);

  /// This month's charges (rent + electricity + extras), excluding carry-forward.
  int get monthCharges => rentAmount + electricBill + extraTotal;

  /// Kept for existing callers; equal to [monthCharges].
  int get totalDue => monthCharges;

  /// This month's balance (charges − paid). Positive means outstanding.
  int get balance => monthCharges - paidAmount;

  int get outstanding => balance > 0 ? balance : 0;

  int get advance => balance < 0 ? -balance : 0;

  bool get isSettled => balance <= 0;

  factory RentRecord.fromMap(String id, Map<String, dynamic> map) => RentRecord(
        month: (map['month'] ?? id) as String,
        rentAmount: asInt(map['rentAmount']),
        prevUnits: asInt(map['prevUnits']),
        currUnits: asInt(map['currUnits']),
        unitPrice: asInt(map['unitPrice']),
        extraCharges: ((map['extraCharges'] ?? const []) as List)
            .map((e) => ExtraCharge.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        payments: ((map['payments'] ?? const []) as List)
            .map((e) => Payment.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        carryForward: asInt(map['carryForward']),
        legacyElectricBill: asInt(map['electricBill']),
        createdAt: tsToDate(map['createdAt']),
      );

  Map<String, dynamic> _fields() => {
        'month': month,
        'rentAmount': rentAmount,
        'prevUnits': prevUnits,
        'currUnits': currUnits,
        'unitPrice': unitPrice,
        // Denormalized amount so exports/legacy readers still see a value.
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
    int? prevUnits,
    int? currUnits,
    int? unitPrice,
    List<ExtraCharge>? extraCharges,
    List<Payment>? payments,
    int? carryForward,
  }) =>
      RentRecord(
        month: month,
        rentAmount: rentAmount ?? this.rentAmount,
        prevUnits: prevUnits ?? this.prevUnits,
        currUnits: currUnits ?? this.currUnits,
        unitPrice: unitPrice ?? this.unitPrice,
        extraCharges: extraCharges ?? this.extraCharges,
        payments: payments ?? this.payments,
        carryForward: carryForward ?? this.carryForward,
        legacyElectricBill: legacyElectricBill,
        createdAt: createdAt,
      );
}
