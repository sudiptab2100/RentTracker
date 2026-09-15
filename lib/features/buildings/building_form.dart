import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../models/building.dart';
import '../../repositories/building_repository.dart';
import '../../widgets/ui_helpers.dart';

Future<void> showBuildingForm(BuildContext context, {Building? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BuildingForm(existing: existing),
  );
}

class _BuildingForm extends ConsumerStatefulWidget {
  const _BuildingForm({this.existing});
  final Building? existing;

  @override
  ConsumerState<_BuildingForm> createState() => _BuildingFormState();
}

class _BuildingFormState extends ConsumerState<_BuildingForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.existing?.address ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.existing != null && widget.existing!.electricityUnitPrice > 0
          ? Money.toEditString(widget.existing!.electricityUnitPrice)
          : '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(buildingRepositoryProvider);
      final building = Building(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        address: _address.text.trim(),
        electricityUnitPrice: Money.parse(_price.text),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      if (widget.existing == null) {
        await repo.create(building);
      } else {
        await repo.update(building);
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
            Text(widget.existing == null ? 'Add building' : 'Edit building',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Building name',
                prefixIcon: Icon(Icons.apartment),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Electricity price per unit',
                prefixText: '\u20B9 ',
                prefixIcon: Icon(Icons.bolt_outlined),
                helperText: 'Applied to all apartments in this building',
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
