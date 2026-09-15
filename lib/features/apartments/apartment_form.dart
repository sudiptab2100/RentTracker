import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/phone_number.dart';
import '../../models/rent_schedule_entry.dart';
import '../../repositories/apartment_repository.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/ui_helpers.dart';
import 'contact_picker.dart';

Future<void> showApartmentForm(
  BuildContext context, {
  required String buildingId,
  required String floorId,
  Apartment? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ApartmentForm(buildingId: buildingId, floorId: floorId, existing: existing),
  );
}

class _ApartmentForm extends ConsumerStatefulWidget {
  const _ApartmentForm({required this.buildingId, required this.floorId, this.existing});
  final String buildingId;
  final String floorId;
  final Apartment? existing;

  @override
  ConsumerState<_ApartmentForm> createState() => _ApartmentFormState();
}

class _ApartmentFormState extends ConsumerState<_ApartmentForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _tenant = TextEditingController(text: widget.existing?.tenantName ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  late final _deposit = TextEditingController(
      text: widget.existing != null && widget.existing!.securityDeposit > 0
          ? Money.toEditString(widget.existing!.securityDeposit)
          : '');
  final _rent = TextEditingController();

  late PhoneNumber _contact = widget.existing?.contact ?? PhoneNumber.empty;
  late PhoneNumber _whatsapp = widget.existing?.whatsapp ?? PhoneNumber.empty;
  late PhoneNumber _emergency = widget.existing?.emergency ?? PhoneNumber.empty;

  String _startMonth = MonthKey.current();
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    for (final c in [_name, _tenant, _address, _deposit, _rent]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStartMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: MonthKey.parse(_startMonth),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2),
      helpText: 'Select rent start month',
    );
    if (picked != null) setState(() => _startMonth = MonthKey.of(picked));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(apartmentRepositoryProvider);

      List<RentScheduleEntry> schedule;
      if (_isNew) {
        final rent = Money.parse(_rent.text);
        schedule = rent > 0
            ? [RentScheduleEntry(effectiveFrom: _startMonth, amount: rent)]
            : const [];
      } else {
        schedule = widget.existing!.rentSchedule;
      }

      final apartment = Apartment(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        tenantName: _tenant.text.trim(),
        address: _address.text.trim(),
        contact: _contact,
        whatsapp: _whatsapp,
        emergency: _emergency,
        securityDeposit: Money.parse(_deposit.text),
        rentSchedule: schedule,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (_isNew) {
        await repo.create(widget.buildingId, widget.floorId, apartment);
      } else {
        await repo.update(widget.buildingId, widget.floorId, apartment);
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
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isNew ? 'Add apartment' : 'Edit apartment',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Unit name / number',
                  hintText: 'e.g. 1A, Flat 302',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Unit name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tenant,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Tenant name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              PhoneField(
                label: 'Contact number',
                icon: Icons.phone_outlined,
                initial: _contact,
                onChanged: (v) => _contact = v,
                onPickContact: () => pickContactPhone(context),
              ),
              const SizedBox(height: 12),
              PhoneField(
                label: 'WhatsApp number',
                icon: Icons.chat_outlined,
                initial: _whatsapp,
                onChanged: (v) => _whatsapp = v,
                onPickContact: () => pickContactPhone(context),
              ),
              const SizedBox(height: 12),
              PhoneField(
                label: 'Emergency contact',
                icon: Icons.emergency_outlined,
                initial: _emergency,
                onChanged: (v) => _emergency = v,
                onPickContact: () => pickContactPhone(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deposit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Security deposit (kept separately)',
                  prefixText: '\u20B9 ',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              if (_isNew) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly rent',
                    prefixText: '\u20B9 ',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    helperText: 'Leave empty for a vacant unit',
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Rent starts from'),
                  subtitle: Text(MonthKey.label(_startMonth)),
                  trailing: TextButton(
                    onPressed: _pickStartMonth,
                    child: const Text('Change'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current rent: ${Money.format(widget.existing!.currentRent)}. '
                          'Use "Update rent" on the apartment to change it.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      ),
    );
  }
}
