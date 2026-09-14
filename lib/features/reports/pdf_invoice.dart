import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/app_config.dart';
import '../../core/month_key.dart';
import '../../core/money.dart';
import '../../models/apartment.dart';
import '../../models/rent_record.dart';

/// PDF-safe money string. The standard PDF fonts don't include the ₹ glyph, so
/// reports use the "Rs." prefix with Indian digit grouping.
String _money(int minor) => 'Rs. ${Money.formatPlain(minor)}';

/// Builds a one-page monthly rent statement/invoice for an apartment.
Future<Uint8List> buildMonthlyReportPdf({
  required String ownerName,
  required String buildingName,
  required String floorName,
  required Apartment apt,
  required RentRecord record,
}) async {
  final doc = pw.Document(title: 'Rent statement ${apt.name} ${record.month}');

  final rows = <List<String>>[
    ['Rent', _money(record.rentAmount)],
    if (record.electricBill > 0) ['Electricity bill', _money(record.electricBill)],
    for (final c in record.extraCharges)
      [c.label.isEmpty ? 'Extra charge' : c.label, _money(c.amount)],
    if (record.carryForward > 0) ['Previous balance', _money(record.carryForward)],
  ];

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(AppConfig.appName,
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Monthly rent statement',
                        style: const pw.TextStyle(color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(MonthKey.label(record.month),
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    if (ownerName.isNotEmpty)
                      pw.Text('Owner: $ownerName',
                          style: const pw.TextStyle(color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.Divider(height: 24),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _kv('Tenant', apt.tenantName.isEmpty ? '-' : apt.tenantName),
                ),
                pw.Expanded(child: _kv('Contact', apt.contactNumber)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Expanded(child: _kv('Building', buildingName)),
                pw.Expanded(child: _kv('Floor', floorName)),
                pw.Expanded(child: _kv('Unit', apt.name)),
              ],
            ),
            if (apt.address.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _kv('Address', apt.address),
            ],
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Description', bold: true),
                    _cell('Amount', bold: true, alignRight: true),
                  ],
                ),
                for (final row in rows)
                  pw.TableRow(children: [
                    _cell(row[0]),
                    _cell(row[1], alignRight: true),
                  ]),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _cell('Total due', bold: true),
                    _cell(_money(record.totalDue), bold: true, alignRight: true),
                  ],
                ),
                pw.TableRow(children: [
                  _cell('Paid'),
                  _cell(_money(record.paidAmount), alignRight: true),
                ]),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: record.isSettled
                        ? PdfColors.green50
                        : PdfColors.red50,
                  ),
                  children: [
                    _cell(record.isSettled ? 'Balance (settled)' : 'Balance due',
                        bold: true),
                    _cell(
                      _money(record.outstanding),
                      bold: true,
                      alignRight: true,
                      color: record.isSettled ? PdfColors.green800 : PdfColors.red800,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            if (apt.securityDeposit > 0)
              pw.Text('Security deposit held separately: ${_money(apt.securityDeposit)}',
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Generated by ${AppConfig.appName} on ${DateTime.now().toString().split('.').first}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _kv(String k, String v) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
        pw.Text(v.isEmpty ? '-' : v, style: const pw.TextStyle(fontSize: 12)),
      ],
    );

pw.Widget _cell(String text,
    {bool bold = false, bool alignRight = false, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}
