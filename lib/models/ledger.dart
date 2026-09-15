import '../core/month_key.dart';
import 'rent_record.dart';

/// One month within a running ledger, carrying the cumulative balance so that
/// unpaid amounts roll forward month to month.
class LedgerLine {
  final RentRecord record;

  /// Cumulative balance before this month (>0 due, <0 advance).
  final int previousBalance;

  /// Cumulative balance through this month.
  final int cumulativeBalance;

  const LedgerLine({
    required this.record,
    required this.previousBalance,
    required this.cumulativeBalance,
  });

  String get month => record.month;
  int get monthCharges => record.monthCharges;
  int get monthPaid => record.paidAmount;
  int get monthBalance => record.balance;
}

/// A running ledger built from an apartment's monthly records. The cumulative
/// balance rolls unpaid dues (and advances) forward across months.
class Ledger {
  /// Ascending by month.
  final List<LedgerLine> lines;

  const Ledger(this.lines);

  factory Ledger.from(Iterable<RentRecord> records) {
    final sorted = [...records]..sort((a, b) => MonthKey.compare(a.month, b.month));
    final lines = <LedgerLine>[];
    var running = 0;
    for (final r in sorted) {
      final previous = running;
      running += r.balance;
      lines.add(LedgerLine(
        record: r,
        previousBalance: previous,
        cumulativeBalance: running,
      ));
    }
    return Ledger(lines);
  }

  bool get isEmpty => lines.isEmpty;

  /// Total cumulative balance (>0 = tenant owes, <=0 = settled/advance).
  int get outstanding => lines.isEmpty ? 0 : lines.last.cumulativeBalance;

  bool get isSettled => outstanding <= 0;

  LedgerLine? lineFor(String month) {
    for (final l in lines) {
      if (l.record.month == month) return l;
    }
    return null;
  }

  /// Cumulative balance strictly before [month] (the "previous month due /
  /// balance" shown on statements), even if [month] has no stored record yet.
  int previousBalanceFor(String month) {
    final line = lineFor(month);
    if (line != null) return line.previousBalance;
    var running = 0;
    for (final l in lines) {
      if (MonthKey.compare(l.record.month, month) < 0) {
        running = l.cumulativeBalance;
      }
    }
    return running;
  }

  /// Cumulative balance through [month] (defaults to the previous cumulative
  /// when the month has no record yet).
  int cumulativeThrough(String month) {
    final line = lineFor(month);
    if (line != null) return line.cumulativeBalance;
    return previousBalanceFor(month);
  }
}
