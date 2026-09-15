import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/ledger.dart';
import '../../models/rent_record.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/floor_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/balance_view.dart';
import '../../widgets/responsive.dart';
import '../../widgets/ui_helpers.dart';
import '../whatsapp/whatsapp_service.dart';
import 'csv_export.dart';
import 'report_text.dart';

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

    final buildingName =
        buildings.where((b) => b.id == buildingId).firstOrNull?.name ?? '';
    final floorName = floors.where((f) => f.id == floorId).firstOrNull?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('Report \u00B7 ${MonthKey.shortLabel(month)}')),
      body: AsyncValueWidget(
        value: apartmentAsync,
        data: (apt) {
          if (apt == null) {
            return const Center(child: Text('Apartment not found'));
          }
          final ledger = Ledger.from(records);
          final record = records.where((r) => r.month == month).firstOrNull ??
              RentRecord(
                month: month,
                rentAmount: apt.rentForMonth(month),
                createdAt: DateTime.now(),
              );
          final text = buildTextReport(
            buildingName: buildingName,
            floorName: floorName,
            apt: apt,
            record: record,
            ledger: ledger,
          );
          final totalPayable = ledger.cumulativeThrough(month);
          final previous = ledger.previousBalanceFor(month);

          return ResponsiveCenter(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportCard(
                apt: apt,
                record: record,
                buildingName: buildingName,
                floorName: floorName,
                previousBalance: previous,
                totalPayable: totalPayable,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _sendReport(context, apt, text),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send report on WhatsApp'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copy(context, text),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy report text'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _shareCsv(context, apt, records, buildingName, floorName),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export rent history (CSV)'),
              ),
              const SizedBox(height: 16),
              Text('Report preview', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send copies the report and opens the tenant\'s WhatsApp chat with '
                'the text pre-filled \u2014 just tap send (or paste if needed).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ));
        },
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showSnack(context, 'Report copied to clipboard');
  }

  Future<void> _sendReport(BuildContext context, Apartment apt, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (apt.whatsapp.isEmpty) {
      if (context.mounted) {
        showSnack(context, 'No WhatsApp number set. Report copied to clipboard.');
      }
      return;
    }
    final ok = await whatsAppService.openChat(phone: apt.whatsapp.e164, text: text);
    if (!ok && context.mounted) {
      showSnack(context, 'Report copied. Could not open WhatsApp.', isError: true);
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
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.apt,
    required this.record,
    required this.buildingName,
    required this.floorName,
    required this.previousBalance,
    required this.totalPayable,
  });

  final Apartment apt;
  final RentRecord record;
  final String buildingName;
  final String floorName;
  final int previousBalance;
  final int totalPayable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rent statement', style: theme.textTheme.titleLarge),
            Text(MonthKey.label(record.month),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const Divider(height: 24),
            _kv(context, 'Tenant', apt.tenantName.isEmpty ? '-' : apt.tenantName),
            _kv(context, 'Apartment',
                '${apt.name}${buildingName.isEmpty ? '' : ' \u00B7 $buildingName'}'
                '${floorName.isEmpty ? '' : ' \u00B7 $floorName'}'),
            const Divider(height: 24),
            _line(context, 'Rent', record.rentAmount),
            if (record.electricBill > 0 || record.hasMeterReadings) ...[
              _line(context, 'Electricity', record.electricBill),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  '${record.currUnits} - ${record.prevUnits} = ${record.unitsUsed} units '
                  '\u00D7 ${Money.format(record.unitPrice)}/unit',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
            for (final c in record.extraCharges)
              if (c.amount != 0)
                _line(context, c.label.isEmpty ? 'Extra charge' : c.label, c.amount),
            if (previousBalance > 0)
              _line(context, 'Previous month due', previousBalance)
            else if (previousBalance < 0)
              _line(context, 'Previous month advance', -previousBalance),
            const Divider(height: 16),
            _line(context, 'This month charges', record.monthCharges, bold: true),
            _line(context, 'Paid this month', record.paidAmount),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalPayable > 0 ? 'Total payable' : 'Balance',
                    style: theme.textTheme.titleMedium),
                BalanceText(balance: totalPayable, style: theme.textTheme.titleMedium),
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
            SizedBox(width: 96, child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
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
