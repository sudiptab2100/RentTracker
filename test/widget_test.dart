import 'package:flutter_test/flutter_test.dart';
import 'package:rent_tracker/core/money.dart';
import 'package:rent_tracker/core/month_key.dart';
import 'package:rent_tracker/models/apartment.dart';
import 'package:rent_tracker/models/extra_charge.dart';
import 'package:rent_tracker/models/ledger_summary.dart';
import 'package:rent_tracker/models/payment.dart';
import 'package:rent_tracker/models/rent_record.dart';
import 'package:rent_tracker/models/rent_schedule_entry.dart';

void main() {
  group('Money', () {
    test('parses major units into paise, tolerating symbols/grouping', () {
      expect(Money.parse('1000'), 100000);
      expect(Money.parse('1,000.50'), 100050);
      expect(Money.parse('\u20B9 2000'), 200000);
      expect(Money.parse(''), 0);
    });

    test('formats and round-trips edit strings', () {
      expect(Money.toEditString(100000), '1000');
      expect(Money.toEditString(100050), '1000.50');
      expect(Money.format(150000), contains('1,500.00'));
    });
  });

  group('MonthKey', () {
    test('navigates months across year boundaries', () {
      expect(MonthKey.next('2026-12'), '2027-01');
      expect(MonthKey.prev('2026-01'), '2025-12');
    });

    test('inclusive range and chronological compare', () {
      expect(MonthKey.range('2026-01', '2026-03'), ['2026-01', '2026-02', '2026-03']);
      expect(MonthKey.range('2026-03', '2026-01'), isEmpty);
      expect(MonthKey.compare('2026-01', '2026-02') < 0, isTrue);
    });
  });

  group('Apartment.rentForMonth', () {
    final apt = Apartment(
      id: 'a',
      name: '1A',
      rentSchedule: const [
        RentScheduleEntry(effectiveFrom: '2026-01', amount: 1000000),
        RentScheduleEntry(effectiveFrom: '2026-06', amount: 1200000),
      ],
      createdAt: DateTime(2026, 1, 1),
    );

    test('uses the effective-dated amount', () {
      expect(apt.rentForMonth('2026-03'), 1000000);
      expect(apt.rentForMonth('2026-06'), 1200000);
      expect(apt.rentForMonth('2026-09'), 1200000);
    });

    test('firstEffectiveMonth is the earliest entry', () {
      expect(apt.firstEffectiveMonth, '2026-01');
    });
  });

  group('RentRecord balance', () {
    RentRecord record({int rent = 1000000, int electric = 0, List<Payment> pays = const []}) {
      return RentRecord(
        month: '2026-09',
        rentAmount: rent,
        electricBill: electric,
        extraCharges: const [ExtraCharge(label: 'Water', amount: 20000)],
        payments: pays,
        createdAt: DateTime(2026, 9, 1),
      );
    }

    test('totalDue sums rent + electricity + extras', () {
      expect(record(electric: 50000).totalDue, 1000000 + 50000 + 20000);
    });

    test('is outstanding (red) when paid < due', () {
      final r = record(pays: [Payment(id: 'p', amount: 500000, date: DateTime(2026, 9, 5))]);
      expect(r.balance > 0, isTrue);
      expect(r.isSettled, isFalse);
    });

    test('is settled (green) when paid >= due', () {
      final r = record(pays: [Payment(id: 'p', amount: 1020000, date: DateTime(2026, 9, 5))]);
      expect(r.balance <= 0, isTrue);
      expect(r.isSettled, isTrue);
      expect(r.outstanding, 0);
    });
  });

  group('LedgerSummary', () {
    test('aggregates due, paid and outstanding across months', () {
      final records = [
        RentRecord(
          month: '2026-08',
          rentAmount: 1000000,
          payments: [Payment(id: '1', amount: 1000000, date: DateTime(2026, 8, 3))],
          createdAt: DateTime(2026, 8, 1),
        ),
        RentRecord(
          month: '2026-09',
          rentAmount: 1000000,
          payments: [Payment(id: '2', amount: 400000, date: DateTime(2026, 9, 3))],
          createdAt: DateTime(2026, 9, 1),
        ),
      ];
      final s = LedgerSummary.from(records);
      expect(s.totalDue, 2000000);
      expect(s.totalPaid, 1400000);
      expect(s.outstanding, 600000);
      expect(s.settledMonths, 1);
    });
  });
}
