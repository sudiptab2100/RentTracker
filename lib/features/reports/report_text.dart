import '../../core/app_config.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/ledger.dart';
import '../../models/rent_record.dart';

/// Builds the plain-text rent statement sent to tenants over WhatsApp.
/// Contains exactly the requested fields, using the running ledger for the
/// previous-month due/advance and the total payable.
String buildTextReport({
  required String buildingName,
  required String floorName,
  required Apartment apt,
  required RentRecord record,
  required Ledger ledger,
}) {
  final month = record.month;
  final previous = ledger.previousBalanceFor(month);
  final totalPayable = ledger.cumulativeThrough(month);

  String money(int v) => Money.format(v);

  final unit = buildingName.isEmpty
      ? apt.name
      : '${apt.name} ($buildingName${floorName.isEmpty ? '' : ', $floorName'})';

  final b = StringBuffer()
    ..writeln('*${AppConfig.appName} - Rent statement*')
    ..writeln(MonthKey.label(month))
    ..writeln('')
    ..writeln('Tenant: ${apt.tenantName.isEmpty ? '-' : apt.tenantName}')
    ..writeln('Apartment: $unit')
    ..writeln('')
    ..writeln('Rent: ${money(record.rentAmount)}');

  if (record.electricBill > 0 || record.hasMeterReadings) {
    b
      ..writeln('Electricity: ${money(record.electricBill)}')
      ..writeln('  - Last month units: ${record.prevUnits}')
      ..writeln('  - Current units: ${record.currUnits}')
      ..writeln('  - Price/unit: ${money(record.unitPrice)}')
      ..writeln('  - (${record.currUnits} - ${record.prevUnits}) x '
          '${money(record.unitPrice)} = ${money(record.electricBill)}');
  }

  for (final c in record.extraCharges) {
    if (c.amount != 0) {
      b.writeln('${c.label.isEmpty ? 'Extra charge' : c.label}: ${money(c.amount)}');
    }
  }

  if (previous > 0) {
    b.writeln('Previous month due: ${money(previous)}');
  } else if (previous < 0) {
    b.writeln('Previous month advance: ${money(-previous)}');
  }

  b
    ..writeln('')
    ..writeln('This month charges: ${money(record.monthCharges)}')
    ..writeln('Paid this month: ${money(record.paidAmount)}')
    ..writeln('');

  if (totalPayable > 0) {
    b.writeln('*Total payable: ${money(totalPayable)}*');
  } else if (totalPayable < 0) {
    b.writeln('*Advance balance: ${money(-totalPayable)}*');
  } else {
    b.writeln('*Settled - nothing due*');
  }

  return b.toString();
}

/// Short pending-rent reminder text.
String buildReminderText({
  required Apartment apt,
  required int outstanding,
  String? month,
}) {
  final name = apt.tenantName.isEmpty ? '' : '${apt.tenantName}, ';
  final forMonth = month == null ? '' : ' for ${MonthKey.label(month)}';
  return 'Hello ${name}this is a friendly reminder that rent$forMonth of '
      '${Money.format(outstanding)} is pending. Kindly clear it at your earliest. Thank you.';
}
