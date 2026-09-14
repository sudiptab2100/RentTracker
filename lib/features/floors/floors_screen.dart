import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/apartment_repository.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/floor_repository.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';
import '../dashboard/dashboard_providers.dart';
import 'floor_form.dart';

class FloorsScreen extends ConsumerWidget {
  const FloorsScreen({super.key, required this.buildingId});
  final String buildingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildings = ref.watch(buildingsProvider).value ?? const [];
    final building = buildings.where((b) => b.id == buildingId).firstOrNull;
    final floors = ref.watch(floorsProvider(buildingId));
    final apartments = ref.watch(ownerApartmentsProvider).value ?? const <ApartmentRef>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(building?.name ?? 'Floors'),
      ),
      floatingActionButton: AsyncValueWidgetFab(
        value: floors,
        builder: (list) => FloatingActionButton.extended(
          onPressed: () =>
              showFloorForm(context, buildingId: buildingId, nextOrder: list.length),
          icon: const Icon(Icons.add),
          label: const Text('Floor'),
        ),
      ),
      body: AsyncValueWidget(
        value: floors,
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.layers_outlined,
              title: 'No floors yet',
              message: 'Add floors to this building, then add apartments.',
              action: FilledButton.icon(
                onPressed: () =>
                    showFloorForm(context, buildingId: buildingId, nextOrder: 0),
                icon: const Icon(Icons.add),
                label: const Text('Add floor'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: list.map((floor) {
              final count = apartments
                  .where((a) => a.buildingId == buildingId && a.floorId == floor.id)
                  .length;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: const Icon(Icons.layers_outlined),
                  ),
                  title: Text(floor.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$count apartment(s)'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        showFloorForm(context, buildingId: buildingId, existing: floor);
                      } else if (value == 'delete') {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete floor?',
                          message:
                              'Deletes "${floor.name}" with all its apartments and rent history.',
                        );
                        if (ok) {
                          try {
                            await ref
                                .read(floorRepositoryProvider)
                                .deleteDeep(buildingId, floor.id);
                            ref.invalidate(portfolioSummaryProvider);
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
                  ),
                  onTap: () =>
                      context.push('/building/$buildingId/floor/${floor.id}'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Small helper that only shows a FAB once the underlying list has loaded.
class AsyncValueWidgetFab<T> extends StatelessWidget {
  const AsyncValueWidgetFab({super.key, required this.value, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.maybeWhen(
      data: builder,
      orElse: () => const SizedBox.shrink(),
    );
  }
}
