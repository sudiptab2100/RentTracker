import 'package:flutter_test/flutter_test.dart';
import 'package:rent_tracker/core/money.dart';
import 'package:rent_tracker/core/month_key.dart';
import 'package:rent_tracker/models/apartment.dart';
import 'package:rent_tracker/models/extra_charge.dart';
import 'package:rent_tracker/models/ledger.dart';
import 'package:rent_tracker/models/ledger_summary.dart';
import 'package:rent_tracker/models/payment.dart';
import 'package:rent_tracker/models/phone_number.dart';
import 'package:rent_tracker/models/rent_record.dart';
import 'package:rent_tracker/models/rent_schedule_entry.dart';

void main() {
  group('Money', () {
    test('parses major units into paise', () {
      expect(Money.parse('1000'), 100000);
      expect(Money.parse('1,000.50'), 100050);
      expect(Money.parse('\u20B9 2000'), 200000);
      expect(Money.parse(''), 0);
    });
    test('edit strings round-trip', () {
      expect(Money.toEditString(100000), '1000');
      expect(Money.toEditString(100050), '1000.50');
    });
  });

  group('MonthKey', () {
    test('navigates across year boundaries', () {
      expect(MonthKey.next('2026-12'), '2027-01');
      expect(MonthKey.prev('2026-01'), '2025-12');
    });
    test('inclusive range', () {
      expect(MonthKey.range('2026-01', '2026-03'), ['2026-01', '2026-02', '2026-03']);
      expect(MonthKey.range('2026-03', '2026-01'), isEmpty);
    });
  });

  group('PhoneNumber', () {
    test('e164 and display', () {
      const p = PhoneNumber(countryCode: '+91', number: '9876543210');
      expect(p.e164, '+919876543210');
      expect(p.e164Digits, '919876543210');
      expect(p.display, '+91 9876543210');
      expect(p.isEmpty, isFalse);
      expect(const PhoneNumber().isEmpty, isTrue);
    });
    test('fromLegacy splits country code and 10-digit number', () {
      expect(PhoneNumber.fromLegacy('9876543210').countryCode, '+91');
      expect(PhoneNumber.fromLegacy('9876543210').number, '9876543210');
      final withCc = PhoneNumber.fromLegacy('+91 98765 43210');
      expect(withCc.countryCode, '+91');
      expect(withCc.number, '9876543210');
      final us = PhoneNumber.fromLegacy('+1 2025550123');
      expect(us.countryCode, '+1');
      expect(us.number, '2025550123');
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
    test('uses effective-dated amount', () {
      expect(apt.rentForMonth('2026-03'), 1000000);
      expect(apt.rentForMonth('2026-06'), 1200000);
      expect(apt.rentForMonth('2026-09'), 1200000);
    });
  });

  group('RentRecord electricity (metered)', () {
    test('bill = (curr - prev) * unitPrice', () {
      final r = RentRecord(
        month: '2026-09',
        rentAmount: 1000000,
        prevUnits: 100,
        currUnits: 180,
        unitPrice: 800, // Rs 8/unit
        createdAt: DateTime(2026, 9, 1),
      );
      expect(r.unitsUsed, 80);
      expect(r.electricBill, 80 * 800);
      expect(r.monthCharges, 1000000 + 80 * 800);
    });
    test('never negative when meter resets', () {
      final r = RentRecord(
        month: '2026-09',
        prevUnits: 200,
        currUnits: 50,
        unitPrice: 800,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(r.unitsUsed, 0);
      expect(r.electricBill, 0);
    });
    test('legacy stored electricBill honored when no meter data', () {
      final r = RentRecord.fromMap('2026-08', {
        'month': '2026-08',
        'rentAmount': 1000000,
        'electricBill': 50000,
        'createdAt': '2026-08-01T00:00:00.000',
      });
      expect(r.electricBill, 50000);
    });
  });

  group('RentRecord balance (per month)', () {
    RentRecord rec({List<Payment> pays = const []}) => RentRecord(
          month: '2026-09',
          rentAmount: 1000000,
          extraCharges: const [ExtraCharge(label: 'Water', amount: 20000)],
          payments: pays,
          createdAt: DateTime(2026, 9, 1),
        );
    test('red when paid < charges', () {
      final r = rec(pays: [Payment(id: 'p', amount: 500000, date: DateTime(2026, 9, 5))]);
      expect(r.balance > 0, isTrue);
      expect(r.isSettled, isFalse);
    });
    test('green when paid >= charges', () {
      final r = rec(pays: [Payment(id: 'p', amount: 1020000, date: DateTime(2026, 9, 5))]);
      expect(r.isSettled, isTrue);
      expect(r.outstanding, 0);
    });
  });

  group('Running ledger', () {
    RentRecord month(String m, int rent, int paid) => RentRecord(
          month: m,
          rentAmount: rent,
          payments: paid > 0 ? [Payment(id: m, amount: paid, date: DateTime(2026, 1, 1))] : const [],
          createdAt: DateTime(2026, 1, 1),
        );

    test('carries unpaid balance forward', () {
      final ledger = Ledger.from([
        month('2026-07', 1000000, 1000000), // settled
        month('2026-08', 1000000, 400000), // 600000 due
        month('2026-09', 1000000, 0), // +1000000
      ]);
      expect(ledger.previousBalanceFor('2026-08'), 0);
      expect(ledger.previousBalanceFor('2026-09'), 600000);
      expect(ledger.cumulativeThrough('2026-09'), 1600000);
      expect(ledger.outstanding, 1600000);
      expect(ledger.isSettled, isFalse);
    });

    test('advance (overpayment) carries as negative', () {
      final ledger = Ledger.from([
        month('2026-08', 1000000, 1200000), // 200000 advance
        month('2026-09', 1000000, 900000), // -100000 net
      ]);
      expect(ledger.previousBalanceFor('2026-09'), -200000);
      expect(ledger.outstanding, -100000);
      expect(ledger.isSettled, isTrue);
    });

    test('previousBalanceFor a not-yet-generated month = full cumulative', () {
      final ledger = Ledger.from([
        month('2026-08', 1000000, 0),
      ]);
      expect(ledger.previousBalanceFor('2026-09'), 1000000);
    });
  });

  group('LedgerSummary', () {
    test('aggregates totals', () {
      final s = LedgerSummary.from([
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
      ]);
      expect(s.totalDue, 2000000);
      expect(s.totalPaid, 1400000);
      expect(s.outstanding, 600000);
    });
  });
}
