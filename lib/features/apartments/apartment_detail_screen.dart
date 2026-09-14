import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/ledger_summary.dart';
import '../../models/rent_record.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/balance_view.dart';
import '../../widgets/ui_helpers.dart';
import '../dashboard/dashboard_providers.dart';
import '../whatsapp/whatsapp_service.dart';
import 'apartment_form.dart';
import '../rent/rent_actions.dart';
import '../rent/rent_engine.dart';

class ApartmentDetailScreen extends ConsumerStatefulWidget {
  const ApartmentDetailScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.apartmentId,
  });

  final String buildingId;
  final String floorId;
  final String apartmentId;

  @override
  ConsumerState<ApartmentDetailScreen> createState() => _ApartmentDetailScreenState();
}

class _ApartmentDetailScreenState extends ConsumerState<ApartmentDetailScreen> {
  bool _generationStarted = false;

  ApartmentPath get _path => (widget.buildingId, widget.floorId, widget.apartmentId);

  Future<void> _ensureGenerated(Apartment apt) async {
    if (_generationStarted) return;
    _generationStarted = true;
    final created =
        await ref.read(rentEngineProvider).ensureGenerated(_path, apt);
    if (created > 0) ref.invalidate(portfolioSummaryProvider);
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showSnack(context, 'Could not open ${uri.scheme}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentAsync = ref.watch(apartmentProvider(_path));
    final recordsAsync = ref.watch(rentRecordsProvider(_path));

    return Scaffold(
      body: AsyncValueWidget(
        value: apartmentAsync,
        data: (apt) {
          if (apt == null) {
            return const Scaffold(body: Center(child: Text('Apartment not found')));
          }
          // Kick off lazy monthly generation once the apartment is known.
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureGenerated(apt));

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(apt.name),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rent') {
                        showRentUpdateSheet(context, path: _path, apt: apt);
                      } else if (value == 'edit') {
                        showApartmentForm(context,
                            buildingId: widget.buildingId,
                            floorId: widget.floorId,
                            existing: apt);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rent', child: Text('Update rent')),
                      PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    ],
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                sliver: SliverList.list(
                  children: [
                    _TenantCard(apt: apt, onLaunch: _launch),
                    const SizedBox(height: 12),
                    recordsAsync.when(
                      loading: () =>
                          const Center(child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator())),
                      error: (e, _) => Text('$e'),
                      data: (records) => _LedgerSection(
                        apt: apt,
                        path: _path,
                        records: records,
                        buildingId: widget.buildingId,
                        floorId: widget.floorId,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.apt, required this.onLaunch});
  final Apartment apt;
  final Future<void> Function(Uri) onLaunch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apt.hasTenant ? apt.tenantName : 'Vacant',
                          style: theme.textTheme.titleMedium),
                      if (apt.address.isNotEmpty)
                        Text(apt.address, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (apt.contactNumber.isNotEmpty)
                  _contactChip(context, Icons.call, 'Call',
                      () => onLaunch(Uri.parse('tel:${apt.contactNumber}'))),
                if (apt.whatsappNumber.isNotEmpty)
                  _contactChip(context, Icons.chat, 'WhatsApp',
                      () => whatsAppService.openChat(phone: apt.whatsappNumber)),
                if (apt.emergencyNumber.isNotEmpty)
                  _contactChip(context, Icons.emergency, 'Emergency',
                      () => onLaunch(Uri.parse('tel:${apt.emergencyNumber}'))),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _miniStat(context, 'Current rent',
                      Money.format(apt.currentRent)),
                ),
                Expanded(
                  child: _miniStat(context, 'Security deposit',
                      Money.format(apt.securityDeposit)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _LedgerSection extends ConsumerWidget {
  const _LedgerSection({
    required this.apt,
    required this.path,
    required this.records,
    required this.buildingId,
    required this.floorId,
  });

  final Apartment apt;
  final ApartmentPath path;
  final List<RentRecord> records;
  final String buildingId;
  final String floorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentMonth = MonthKey.current();
    final current = records.where((r) => r.month == currentMonth).firstOrNull;
    final summary = LedgerSummary.from(records);

    if (apt.rentSchedule.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 40),
              const SizedBox(height: 8),
              const Text('No rent set for this apartment yet.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showRentUpdateSheet(context, path: path, apt: apt),
                icon: const Icon(Icons.add),
                label: const Text('Set rent'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrentMonthCard(
          apt: apt,
          path: path,
          month: currentMonth,
          record: current,
          buildingId: buildingId,
          floorId: floorId,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rent history', style: theme.textTheme.titleMedium),
              Text(
                'Outstanding: ${Money.format(summary.outstanding)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: summary.isSettled
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...records.map((r) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(MonthKey.label(r.month)),
                subtitle: Text(
                    'Due ${Money.format(r.totalDue)} · Paid ${Money.format(r.paidAmount)}'),
                trailing: BalanceChip(balance: r.balance),
                onTap: () => context.push(
                    '/building/$buildingId/floor/$floorId/apt/${apt.id}/report/${r.month}'),
              ),
            )),
      ],
    );
  }
}

class _CurrentMonthCard extends ConsumerWidget {
  const _CurrentMonthCard({
    required this.apt,
    required this.path,
    required this.month,
    required this.record,
    required this.buildingId,
    required this.floorId,
  });

  final Apartment apt;
  final ApartmentPath path;
  final String month;
  final RentRecord? record;
  final String buildingId;
  final String floorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rec = record ??
        RentRecord(month: month, rentAmount: apt.rentForMonth(month), createdAt: DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(MonthKey.label(month), style: theme.textTheme.titleMedium),
                BalanceChip(balance: rec.balance),
              ],
            ),
            const Divider(height: 20),
            _line(context, 'Rent', rec.rentAmount),
            if (rec.electricBill > 0) _line(context, 'Electricity', rec.electricBill),
            for (final c in rec.extraCharges)
              _line(context, c.label.isEmpty ? 'Extra charge' : c.label, c.amount),
            const Divider(height: 20),
            _line(context, 'Total due', rec.totalDue, bold: true),
            _line(context, 'Paid', rec.paidAmount),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rec.isSettled ? 'Balance' : 'Balance due',
                    style: theme.textTheme.titleSmall),
                BalanceText(balance: rec.balance, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      showPaymentSheet(context, path: path, apt: apt, month: month),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Payment'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      showElectricBillSheet(context, path: path, apt: apt, record: rec),
                  icon: const Icon(Icons.bolt_outlined, size: 18),
                  label: const Text('Electricity'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      showChargesSheet(context, path: path, apt: apt, record: rec),
                  icon: const Icon(Icons.add_chart_outlined, size: 18),
                  label: const Text('Charges'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                      '/building/$buildingId/floor/$floorId/apt/${apt.id}/report/$month'),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Report'),
                ),
                if (rec.balance > 0 && apt.whatsappNumber.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _sendReminder(context, apt, rec),
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Remind'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReminder(
      BuildContext context, Apartment apt, RentRecord rec) async {
    final message = 'Hello ${apt.tenantName.isEmpty ? '' : '${apt.tenantName}, '}'
        'this is a friendly reminder that rent for ${MonthKey.label(rec.month)} '
        'of ${Money.format(rec.balance)} is pending. Thank you.';
    final ok = await whatsAppService.openChat(phone: apt.whatsappNumber, text: message);
    if (!ok && context.mounted) {
      showSnack(context, 'Could not open WhatsApp', isError: true);
    }
  }

  Widget _line(BuildContext context, String label, int amount, {bool bold = false}) {
    final style = bold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(Money.format(amount), style: style),
        ],
      ),
    );
  }
}
