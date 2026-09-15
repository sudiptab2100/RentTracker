import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/floor_repository.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/balance_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';
import '../dashboard/dashboard_providers.dart';
import 'apartment_form.dart';

class ApartmentsScreen extends ConsumerWidget {
  const ApartmentsScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
  });

  final String buildingId;
  final String floorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floors = ref.watch(floorsProvider(buildingId)).value ?? const [];
    final floor = floors.where((f) => f.id == floorId).firstOrNull;
    final apartments = ref.watch(apartmentsProvider((buildingId, floorId)));
    final overview = ref.watch(overviewProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(floor?.name ?? 'Apartments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showApartmentForm(context, buildingId: buildingId, floorId: floorId),
        icon: const Icon(Icons.add),
        label: const Text('Apartment'),
      ),
      body: AsyncValueWidget(
        value: apartments,
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No apartments yet',
              message: 'Add apartments to this floor and set their rent.',
              action: FilledButton.icon(
                onPressed: () => showApartmentForm(context,
                    buildingId: buildingId, floorId: floorId),
                icon: const Icon(Icons.add),
                label: const Text('Add apartment'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: list.map((apt) {
              final status = overview?.apartments
                  .where((a) => a.apartment.id == apt.id)
                  .firstOrNull;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.tertiaryContainer,
                    child: const Icon(Icons.meeting_room_outlined),
                  ),
                  title: Text(apt.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apt.hasTenant ? apt.tenantName : 'Vacant'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (status != null)
                            BalanceChip(balance: status.balance)
                          else
                            const SizedBox.shrink(),
                          const SizedBox(width: 8),
                          if (apt.currentRent > 0)
                            Text('Rent ${Money.format(apt.currentRent)}',
                                style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        showApartmentForm(context,
                            buildingId: buildingId,
                            floorId: floorId,
                            existing: apt);
                      } else if (value == 'delete') {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete apartment?',
                          message:
                              'Deletes "${apt.name}" and all of its rent history.',
                        );
                        if (ok) {
                          try {
                            await ref
                                .read(apartmentRepositoryProvider)
                                .deleteDeep(buildingId, floorId, apt.id);
                            ref.invalidate(overviewProvider);
                          } catch (e) {
                            if (context.mounted) {
                              showSnack(context, '$e', isError: true);
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => context.push(
                      '/building/$buildingId/floor/$floorId/apt/${apt.id}'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
