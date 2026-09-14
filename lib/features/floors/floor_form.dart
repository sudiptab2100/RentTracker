import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/floor.dart';
import '../../repositories/floor_repository.dart';
import '../../widgets/ui_helpers.dart';

Future<void> showFloorForm(
  BuildContext context, {
  required String buildingId,
  Floor? existing,
  int nextOrder = 0,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _FloorForm(buildingId: buildingId, existing: existing, nextOrder: nextOrder),
  );
}

class _FloorForm extends ConsumerStatefulWidget {
  const _FloorForm({required this.buildingId, this.existing, this.nextOrder = 0});
  final String buildingId;
  final Floor? existing;
  final int nextOrder;

  @override
  ConsumerState<_FloorForm> createState() => _FloorFormState();
}

class _FloorFormState extends ConsumerState<_FloorForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _order = TextEditingController(
      text: (widget.existing?.order ?? widget.nextOrder).toString());
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(floorRepositoryProvider);
      final floor = Floor(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        order: int.tryParse(_order.text.trim()) ?? 0,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      if (widget.existing == null) {
        await repo.create(widget.buildingId, floor);
      } else {
        await repo.update(widget.buildingId, floor);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Add floor' : 'Edit floor',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Floor name / number',
                hintText: 'e.g. Ground, 1st Floor',
                prefixIcon: Icon(Icons.layers_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _order,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sort order',
                helperText: 'Lower numbers appear first',
                prefixIcon: Icon(Icons.sort),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
