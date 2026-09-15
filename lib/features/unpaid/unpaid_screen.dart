import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../../widgets/ui_helpers.dart';
import '../dashboard/dashboard_providers.dart';
import '../reports/report_text.dart';
import '../whatsapp/whatsapp_service.dart';

class UnpaidScreen extends ConsumerStatefulWidget {
  const UnpaidScreen({super.key});

  @override
  ConsumerState<UnpaidScreen> createState() => _UnpaidScreenState();
}

class _UnpaidScreenState extends ConsumerState<UnpaidScreen> {
  String? _buildingId;
  String? _floorId;
  String? _apartmentId;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(overviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unpaid rent'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(overviewProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overviewProvider);
          await ref.read(overviewProvider.future);
        },
        child: AsyncValueWidget(
          value: overview,
          onRetry: () => ref.invalidate(overviewProvider),
          data: (data) => _body(context, data),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Overview data) {
    // Distinct filter options derived from the portfolio.
    final buildings = <String, String>{};
    final floors = <String, String>{};
    final apartments = <String, String>{};
    for (final a in data.apartments) {
      buildings[a.buildingId] = a.buildingName.isEmpty ? 'Building' : a.buildingName;
      if (_buildingId == null || a.buildingId == _buildingId) {
        floors[a.floorId] = a.floorName.isEmpty ? 'Floor' : a.floorName;
      }
      if ((_buildingId == null || a.buildingId == _buildingId) &&
          (_floorId == null || a.floorId == _floorId)) {
        apartments[a.apartment.id] = a.apartment.name;
      }
    }

    var due = data.dueList;
    if (_buildingId != null) due = due.where((a) => a.buildingId == _buildingId).toList();
    if (_floorId != null) due = due.where((a) => a.floorId == _floorId).toList();
    if (_apartmentId != null) {
      due = due.where((a) => a.apartment.id == _apartmentId).toList();
    }

    final totalDue = due.fold<int>(0, (s, a) => s + a.outstanding);

    return ResponsiveCenter(child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _filters(context, buildings, floors, apartments),
        const SizedBox(height: 8),
        Card(
          color: const Color(0xFFC62828).withValues(alpha: 0.08),
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFFC62828)),
            title: const Text('Total pending'),
            subtitle: Text('${due.length} tenant(s) with dues'),
            trailing: Text(
              Money.format(totalDue),
              style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (due.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All settled',
              message: 'No tenants have pending rent for the current filters.',
            ),
          )
        else
          ...due.map((a) => _UnpaidTile(overview: a)),
      ],
    ));
  }

  Widget _filters(
    BuildContext context,
    Map<String, String> buildings,
    Map<String, String> floors,
    Map<String, String> apartments,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _dropdown(
          hint: 'All buildings',
          value: _buildingId,
          items: buildings,
          onChanged: (v) => setState(() {
            _buildingId = v;
            _floorId = null;
            _apartmentId = null;
          }),
        ),
        _dropdown(
          hint: 'All floors',
          value: _floorId,
          items: floors,
          onChanged: (v) => setState(() {
            _floorId = v;
            _apartmentId = null;
          }),
        ),
        _dropdown(
          hint: 'All units',
          value: _apartmentId,
          items: apartments,
          onChanged: (v) => setState(() => _apartmentId = v),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 168,
      child: DropdownButtonFormField<String?>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true),
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _UnpaidTile extends StatelessWidget {
  const _UnpaidTile({required this.overview});
  final ApartmentOverview overview;

  @override
  Widget build(BuildContext context) {
    final apt = overview.apartment;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        title: Text(apt.hasTenant ? apt.tenantName : 'Vacant',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${apt.name} \u00B7 ${overview.buildingName}'
          '${overview.floorName.isEmpty ? '' : ' \u00B7 ${overview.floorName}'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Money.format(overview.outstanding),
                style: const TextStyle(
                    color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
            if (apt.whatsapp.isNotEmpty)
              TextButton.icon(
                onPressed: () => _remind(context),
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: const Text('Remind'),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact),
              ),
          ],
        ),
        onTap: () => context.push(
            '/building/${overview.buildingId}/floor/${overview.floorId}/apt/${apt.id}'),
      ),
    );
  }

  Future<void> _remind(BuildContext context) async {
    final message =
        buildReminderText(apt: overview.apartment, outstanding: overview.outstanding);
    final ok = await whatsAppService.openChat(
        phone: overview.apartment.whatsapp.e164, text: message);
    if (!ok && context.mounted) {
      showSnack(context, 'Could not open WhatsApp', isError: true);
    }
  }
}
