import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/rent_record.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/floor_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../services/firebase_providers.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/balance_view.dart';
import '../../widgets/ui_helpers.dart';
import '../whatsapp/whatsapp_service.dart';
import 'csv_export.dart';
import 'pdf_invoice.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.apartmentId,
    required this.month,
  });

  final String buildingId;
  final String floorId;
  final String apartmentId;
  final String month;

  ApartmentPath get _path => (buildingId, floorId, apartmentId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartmentAsync = ref.watch(apartmentProvider(_path));
    final records = ref.watch(rentRecordsProvider(_path)).value ?? const <RentRecord>[];
    final buildings = ref.watch(buildingsProvider).value ?? const [];
    final floors = ref.watch(floorsProvider(buildingId)).value ?? const [];
    final owner = ref.watch(currentUserProvider);

    final buildingName =
        buildings.where((b) => b.id == buildingId).firstOrNull?.name ?? '';
    final floorName = floors.where((f) => f.id == floorId).firstOrNull?.name ?? '';
    final ownerName = owner?.displayName ?? owner?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('Report · ${MonthKey.shortLabel(month)}')),
      body: AsyncValueWidget(
        value: apartmentAsync,
        data: (apt) {
          if (apt == null) {
            return const Center(child: Text('Apartment not found'));
          }
          final record = records.where((r) => r.month == month).firstOrNull ??
              RentRecord(
                month: month,
                rentAmount: apt.rentForMonth(month),
                createdAt: DateTime.now(),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportCard(
                apt: apt,
                record: record,
                buildingName: buildingName,
                floorName: floorName,
              ),
              const SizedBox(height: 20),
              Text('Share & export',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _printPdf(apt, record, buildingName, floorName, ownerName),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Preview / Print PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _sharePdf(
                    context, apt, record, buildingName, floorName, ownerName),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Send PDF via WhatsApp / share'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _shareCsv(context, apt, records, buildingName, floorName),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export rent history (CSV)'),
              ),
              if (apt.whatsappNumber.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openChat(context, apt, record),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Open tenant WhatsApp chat'),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Note: WhatsApp cannot silently attach files, so the PDF opens in '
                'the share sheet — pick WhatsApp and tap send.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printPdf(Apartment apt, RentRecord record, String b, String f,
      String owner) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildMonthlyReportPdf(
        ownerName: owner,
        buildingName: b,
        floorName: f,
        apt: apt,
        record: record,
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context, Apartment apt, RentRecord record,
      String b, String f, String owner) async {
    try {
      final bytes = await buildMonthlyReportPdf(
        ownerName: owner,
        buildingName: b,
        floorName: f,
        apt: apt,
        record: record,
      );
      final filename =
          'Rent_${apt.name}_${record.month}.pdf'.replaceAll(RegExp(r'\s+'), '_');
      final caption = 'Rent statement for ${MonthKey.label(record.month)} — '
          '${apt.name}. Balance: ${Money.format(record.outstanding)}.';
      await whatsAppService.shareBytes(bytes, filename,
          text: caption, subject: 'Rent statement ${record.month}');
    } catch (e) {
      if (context.mounted) showSnack(context, '$e', isError: true);
    }
  }

  Future<void> _shareCsv(BuildContext context, Apartment apt,
      List<RentRecord> records, String b, String f) async {
    try {
      final csv = CsvExport.apartmentHistory(b, f, apt, records);
      final filename = 'Rent_history_${apt.name}.csv'.replaceAll(RegExp(r'\s+'), '_');
      await whatsAppService.shareBytes(
        Uint8List.fromList(utf8.encode(csv)),
        filename,
        subject: 'Rent history ${apt.name}',
      );
    } catch (e) {
      if (context.mounted) showSnack(context, '$e', isError: true);
    }
  }

  Future<void> _openChat(
      BuildContext context, Apartment apt, RentRecord record) async {
    final message = record.balance > 0
        ? 'Hello ${apt.tenantName}, rent for ${MonthKey.label(record.month)} '
            'of ${Money.format(record.balance)} is pending.'
        : 'Hello ${apt.tenantName}, thank you — rent for '
            '${MonthKey.label(record.month)} is fully settled.';
    final ok = await whatsAppService.openChat(phone: apt.whatsappNumber, text: message);
    if (!ok && context.mounted) {
      showSnack(context, 'Could not open WhatsApp', isError: true);
    }
  }
}

/// Encodes a string as UTF-8 bytes for sharing.

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.apt,
    required this.record,
    required this.buildingName,
    required this.floorName,
  });

  final Apartment apt;
  final RentRecord record;
  final String buildingName;
  final String floorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly rent statement', style: theme.textTheme.titleLarge),
            Text(MonthKey.label(record.month),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const Divider(height: 24),
            _kv(context, 'Tenant', apt.tenantName.isEmpty ? '-' : apt.tenantName),
            _kv(context, 'Unit', '$buildingName · $floorName · ${apt.name}'),
            if (apt.contactNumber.isNotEmpty)
              _kv(context, 'Contact', apt.contactNumber),
            const Divider(height: 24),
            _line(context, 'Rent', record.rentAmount),
            if (record.electricBill > 0)
              _line(context, 'Electricity', record.electricBill),
            for (final c in record.extraCharges)
              _line(context, c.label.isEmpty ? 'Extra charge' : c.label, c.amount),
            const Divider(height: 16),
            _line(context, 'Total due', record.totalDue, bold: true),
            _line(context, 'Paid', record.paidAmount),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(record.isSettled ? 'Balance (settled)' : 'Balance due',
                    style: theme.textTheme.titleMedium),
                BalanceText(balance: record.balance, style: theme.textTheme.titleMedium),
              ],
            ),
            if (apt.securityDeposit > 0) ...[
              const SizedBox(height: 12),
              Text('Security deposit held separately: ${Money.format(apt.securityDeposit)}',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: Text(v)),
          ],
        ),
      );

  Widget _line(BuildContext context, String label, int amount, {bool bold = false}) {
    final style = bold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(Money.format(amount), style: style)],
      ),
    );
  }
}
