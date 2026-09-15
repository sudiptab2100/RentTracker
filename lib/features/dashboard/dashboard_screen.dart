import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/money.dart';
import '../../models/building.dart';
import '../../repositories/building_repository.dart';
import '../../services/firebase_providers.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/balance_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../../widgets/ui_helpers.dart';
import '../buildings/building_form.dart';
import '../search/apartment_search_delegate.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildings = ref.watch(buildingsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/icon/app_logo.png', width: 28, height: 28),
            ),
            const SizedBox(width: 8),
            const Text(AppConfig.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search tenants',
            icon: const Icon(Icons.search),
            onPressed: () async {
              final apts = ref.read(overviewProvider).value?.apartments ??
                  const <ApartmentOverview>[];
              final selected = await showSearch<ApartmentOverview?>(
                context: context,
                delegate: ApartmentSearchDelegate(apts),
              );
              if (selected != null && context.mounted) {
                context.push(
                    '/building/${selected.buildingId}/floor/${selected.floorId}/apt/${selected.apartment.id}');
              }
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBuildingForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Building'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(buildingsProvider);
          ref.invalidate(overviewProvider);
          await ref.read(overviewProvider.future);
        },
        child: AsyncValueWidget(
          value: buildings,
          data: (list) => ResponsiveCenter(child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              _WelcomeHeader(name: user?.displayName ?? user?.email ?? ''),
              const SizedBox(height: 8),
              const _SummaryCard(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Buildings',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 4),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'No buildings yet',
                    message: 'Add your first building to start tracking rent.',
                    action: FilledButton.icon(
                      onPressed: () => showBuildingForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add building'),
                    ),
                  ),
                )
              else
                ...list.map((b) => _BuildingCard(building: b)),
            ],
          )),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        name.isEmpty ? 'Welcome' : 'Welcome, ${name.split('@').first}',
        style: theme.textTheme.headlineSmall,
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(overviewProvider);
    final buildings = ref.watch(buildingsProvider).value ?? const <Building>[];
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Portfolio', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Could not load summary: $e',
                  style: theme.textTheme.bodySmall),
              data: (s) => Column(
                children: [
                  Row(
                    children: [
                      _stat(context, '${buildings.length}', 'Buildings'),
                      _stat(context, '${s.apartmentCount}', 'Apartments'),
                      _stat(context, '${s.tenantCount}', 'Tenants'),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total outstanding',
                              style: theme.textTheme.bodyMedium),
                          Text('${s.dueCount} unit(s) with pending rent',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                      BalanceText(
                        balance: s.totalOutstanding,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _BuildingCard extends ConsumerWidget {
  const _BuildingCard({required this.building});
  final Building building;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(overviewProvider).value;
    final apartments = summary?.apartmentsForBuilding(building.id) ?? 0;
    final due = summary?.dueCountForBuilding(building.id) ?? 0;
    final outstanding = summary?.outstandingForBuilding(building.id) ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.apartment),
        ),
        title: Text(building.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (building.address.isNotEmpty) Text(building.address),
            const SizedBox(height: 4),
            Text('$apartments apartment(s)'
                '${due > 0 ? ' · $due due' : ''}'),
          ],
        ),
        isThreeLine: building.address.isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (outstanding > 0)
              Text(Money.format(outstanding),
                  style: const TextStyle(
                      color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
            _buildingMenu(context, ref),
          ],
        ),
        onTap: () => context.push('/building/${building.id}'),
      ),
    );
  }

  Widget _buildingMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') {
          showBuildingForm(context, existing: building);
        } else if (value == 'delete') {
          final ok = await confirmDialog(
            context,
            title: 'Delete building?',
            message:
                'This permanently deletes "${building.name}" and all its floors, '
                'apartments and rent history.',
          );
          if (ok) {
            try {
              await ref.read(buildingRepositoryProvider).deleteDeep(building.id);
              ref.invalidate(overviewProvider);
            } catch (e) {
              if (context.mounted) showSnack(context, '$e', isError: true);
            }
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
