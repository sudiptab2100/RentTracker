import 'rent_record.dart';

/// Aggregated money across a set of monthly [RentRecord]s for one apartment.
class LedgerSummary {
  final int totalDue;
  final int totalPaid;
  final int monthsCount;
  final int settledMonths;

  const LedgerSummary({
    required this.totalDue,
    required this.totalPaid,
    required this.monthsCount,
    required this.settledMonths,
  });

  /// Net outstanding across all months. Positive means the tenant owes money.
  int get outstanding => totalDue - totalPaid;

  bool get isSettled => outstanding <= 0;

  factory LedgerSummary.from(Iterable<RentRecord> records) {
    var due = 0;
    var paid = 0;
    var months = 0;
    var settled = 0;
    for (final r in records) {
      due += r.totalDue;
      paid += r.paidAmount;
      months++;
      if (r.isSettled) settled++;
    }
    return LedgerSummary(
      totalDue: due,
      totalPaid: paid,
      monthsCount: months,
      settledMonths: settled,
    );
  }
}
