import 'package:csv/csv.dart';

import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/ledger_summary.dart';
import '../../models/master_export.dart';
import '../../models/rent_record.dart';

/// Builders that turn app data into CSV strings for record-keeping/export.
class CsvExport {
  static final _c = CsvEncoder();

  static String _rupees(int minor) => (minor / 100).toStringAsFixed(2);

  /// Monthly ledger for a single apartment.
  static String apartmentHistory(
    String buildingName,
    String floorName,
    Apartment apt,
    List<RentRecord> records,
  ) {
    final rows = <List<dynamic>>[
      [
        'Month',
        'Rent',
        'Units used',
        'Electricity',
        'Extra charges',
        'Total due',
        'Paid',
        'Balance',
        'Status',
      ],
    ];
    final sorted = [...records]..sort((a, b) => MonthKey.compare(a.month, b.month));
    for (final r in sorted) {
      rows.add([
        r.month,
        _rupees(r.rentAmount),
        r.unitsUsed,
        _rupees(r.electricBill),
        _rupees(r.extraTotal),
        _rupees(r.totalDue),
        _rupees(r.paidAmount),
        _rupees(r.outstanding),
        r.isSettled ? 'Settled' : 'Due',
      ]);
    }
    return _c.convert(rows);
  }

  /// One row per tenant/apartment across the whole portfolio.
  static String masterTenants(MasterExport data) {
    final rows = <List<dynamic>>[
      [
        'Building',
        'Floor',
        'Unit',
        'Tenant',
        'Contact',
        'WhatsApp',
        'Emergency',
        'Address',
        'Security deposit',
        'Current rent',
        'Total due',
        'Total paid',
        'Outstanding',
      ],
    ];
    for (final b in data.buildings) {
      for (final f in b.floors) {
        for (final ae in f.apartments) {
          final apt = ae.apartment;
          final summary = LedgerSummary.from(ae.rentRecords);
          rows.add([
            b.building.name,
            f.floor.name,
            apt.name,
            apt.tenantName,
            apt.contact.display,
            apt.whatsapp.display,
            apt.emergency.display,
            apt.address,
            _rupees(apt.securityDeposit),
            _rupees(apt.currentRent),
            _rupees(summary.totalDue),
            _rupees(summary.totalPaid),
            _rupees(summary.outstanding),
          ]);
        }
      }
    }
    return _c.convert(rows);
  }

  /// One row per month per apartment across the whole portfolio.
  static String masterLedger(MasterExport data) {
    final rows = <List<dynamic>>[
      [
        'Building',
        'Floor',
        'Unit',
        'Tenant',
        'Month',
        'Rent',
        'Electricity',
        'Extra charges',
        'Total due',
        'Paid',
        'Balance',
        'Status',
      ],
    ];
    for (final b in data.buildings) {
      for (final f in b.floors) {
        for (final ae in f.apartments) {
          final apt = ae.apartment;
          final sorted = [...ae.rentRecords]
            ..sort((x, y) => MonthKey.compare(x.month, y.month));
          for (final r in sorted) {
            rows.add([
              b.building.name,
              f.floor.name,
              apt.name,
              apt.tenantName,
              r.month,
              _rupees(r.rentAmount),
              _rupees(r.electricBill),
              _rupees(r.extraTotal),
              _rupees(r.totalDue),
              _rupees(r.paidAmount),
              _rupees(r.outstanding),
              r.isSettled ? 'Settled' : 'Due',
            ]);
          }
        }
      }
    }
    return _c.convert(rows);
  }
}
