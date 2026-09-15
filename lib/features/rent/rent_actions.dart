import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/extra_charge.dart';
import '../../models/rent_record.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../widgets/ui_helpers.dart';
import 'rent_engine.dart';

Future<void> showPaymentSheet(
  BuildContext context, {
  required ApartmentPath path,
  required Apartment apt,
  required String month,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PaymentSheet(path: path, apt: apt, month: month),
  );
}

Future<void> showElectricBillSheet(
  BuildContext context, {
  required ApartmentPath path,
  required Apartment apt,
  required RentRecord record,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ElectricSheet(path: path, apt: apt, record: record),
  );
}

Future<void> showChargesSheet(
  BuildContext context, {
  required ApartmentPath path,
  required Apartment apt,
  required RentRecord record,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ChargesSheet(path: path, apt: apt, record: record),
  );
}

Future<void> showRentUpdateSheet(
  BuildContext context, {
  required ApartmentPath path,
  required Apartment apt,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RentUpdateSheet(path: path, apt: apt),
  );
}

Widget _sheetWrap(BuildContext context, {required List<Widget> children}) {
  return Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 8,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

// ---- Payment ---------------------------------------------------------------

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.path, required this.apt, required this.month});
  final ApartmentPath path;
  final Apartment apt;
  final String month;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.parse(_amount.text);
    if (amount <= 0) {
      showSnack(context, 'Enter a valid amount', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(rentEngineProvider).addPayment(
            widget.path,
            widget.apt,
            widget.month,
            amount: amount,
            date: _date,
            note: _note.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetWrap(context, children: [
      Text('Record payment · ${MonthKey.label(widget.month)}',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount received',
          prefixText: '\u20B9 ',
          prefixIcon: Icon(Icons.payments_outlined),
        ),
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: const Text('Payment date'),
        subtitle: Text(DateFormat('d MMM yyyy').format(_date)),
        trailing: TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: const Text('Change'),
        ),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: _note,
        decoration: const InputDecoration(
          labelText: 'Note (optional)',
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Add payment'),
      ),
    ]);
  }
}

// ---- Electricity -----------------------------------------------------------

class _ElectricSheet extends ConsumerStatefulWidget {
  const _ElectricSheet({required this.path, required this.apt, required this.record});
  final ApartmentPath path;
  final Apartment apt;
  final RentRecord record;

  @override
  ConsumerState<_ElectricSheet> createState() => _ElectricSheetState();
}

class _ElectricSheetState extends ConsumerState<_ElectricSheet> {
  late final _prev = TextEditingController(
      text: widget.record.prevUnits > 0 ? widget.record.prevUnits.toString() : '');
  late final _curr = TextEditingController(
      text: widget.record.currUnits > 0 ? widget.record.currUnits.toString() : '');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillPrevReading();
  }

  Future<void> _prefillPrevReading() async {
    if (widget.record.prevUnits != 0 || _prev.text.isNotEmpty) return;
    final prevMonth = MonthKey.prev(widget.record.month);
    final prevRec = await ref.read(rentRepositoryProvider).getRecord(widget.path, prevMonth);
    if (prevRec != null && prevRec.currUnits > 0 && mounted && _prev.text.isEmpty) {
      setState(() => _prev.text = prevRec.currUnits.toString());
    }
  }

  int get _unitPrice {
    final buildings = ref.watch(buildingsProvider).value ?? const [];
    final b = buildings.where((x) => x.id == widget.path.$1).firstOrNull;
    return b?.electricityUnitPrice ?? 0;
  }

  @override
  void dispose() {
    _prev.dispose();
    _curr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prev = int.tryParse(_prev.text.trim()) ?? 0;
    final curr = int.tryParse(_curr.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await ref.read(rentEngineProvider).setElectricReading(
            widget.path,
            widget.apt,
            widget.record.month,
            prevUnits: prev,
            currUnits: curr,
            unitPrice: _unitPrice,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = _unitPrice;
    final prev = int.tryParse(_prev.text.trim()) ?? 0;
    final curr = int.tryParse(_curr.text.trim()) ?? 0;
    final used = (curr - prev) > 0 ? curr - prev : 0;
    final bill = used * price;

    return _sheetWrap(context, children: [
      Text('Electricity \u00B7 ${MonthKey.label(widget.record.month)}',
          style: theme.textTheme.titleLarge),
      const SizedBox(height: 6),
      if (price == 0)
        Text('Set this building\'s price per unit first (Building \u2192 Edit).',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFC62828)))
      else
        Text('Price per unit: ${Money.format(price)}',
            style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _prev,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Last reading',
                suffixText: 'units',
                prefixIcon: Icon(Icons.history),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _curr,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Current reading',
                suffixText: 'units',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$used unit(s) used', style: theme.textTheme.bodyMedium),
            Text(Money.format(bill),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Save'),
      ),
    ]);
  }
}

// ---- Extra charges ---------------------------------------------------------

class _ChargesSheet extends ConsumerStatefulWidget {
  const _ChargesSheet({required this.path, required this.apt, required this.record});
  final ApartmentPath path;
  final Apartment apt;
  final RentRecord record;

  @override
  ConsumerState<_ChargesSheet> createState() => _ChargesSheetState();
}

class _ChargeRow {
  final TextEditingController label;
  final TextEditingController amount;
  _ChargeRow(String l, int a)
      : label = TextEditingController(text: l),
        amount = TextEditingController(text: a > 0 ? Money.toEditString(a) : '');
}

class _ChargesSheetState extends ConsumerState<_ChargesSheet> {
  late final List<_ChargeRow> _rows = widget.record.extraCharges
      .map((c) => _ChargeRow(c.label, c.amount))
      .toList();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_rows.isEmpty) _rows.add(_ChargeRow('', 0));
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.label.dispose();
      r.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final charges = <ExtraCharge>[];
    for (final r in _rows) {
      final amount = Money.parse(r.amount.text);
      final label = r.label.text.trim();
      if (amount > 0 || label.isNotEmpty) {
        charges.add(ExtraCharge(label: label, amount: amount));
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(rentEngineProvider).setExtraCharges(
            widget.path,
            widget.apt,
            widget.record.month,
            charges,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetWrap(context, children: [
      Text('Extra charges · ${MonthKey.label(widget.record.month)}',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ..._rows.asMap().entries.map((e) {
        final row = e.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: row.label,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '\u20B9 '),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  row.label.dispose();
                  row.amount.dispose();
                  _rows.removeAt(e.key);
                  if (_rows.isEmpty) _rows.add(_ChargeRow('', 0));
                }),
              ),
            ],
          ),
        );
      }),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _rows.add(_ChargeRow('', 0))),
          icon: const Icon(Icons.add),
          label: const Text('Add charge'),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Save charges'),
      ),
    ]);
  }
}

// ---- Rent update -----------------------------------------------------------

class _RentUpdateSheet extends ConsumerStatefulWidget {
  const _RentUpdateSheet({required this.path, required this.apt});
  final ApartmentPath path;
  final Apartment apt;

  @override
  ConsumerState<_RentUpdateSheet> createState() => _RentUpdateSheetState();
}

class _RentUpdateSheetState extends ConsumerState<_RentUpdateSheet> {
  late final _amount =
      TextEditingController(text: Money.toEditString(widget.apt.currentRent));
  bool _effectiveThisMonth = false;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.parse(_amount.text);
    if (amount <= 0) {
      showSnack(context, 'Enter a valid rent amount', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(rentEngineProvider).updateRent(
            widget.path,
            widget.apt,
            amount,
            effectiveThisMonth: _effectiveThisMonth,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextMonth = MonthKey.label(MonthKey.next(MonthKey.current()));
    final thisMonth = MonthKey.label(MonthKey.current());
    return _sheetWrap(context, children: [
      Text('Update rent', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text('Current: ${Money.format(widget.apt.currentRent)}',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'New monthly rent',
          prefixText: '\u20B9 ',
          prefixIcon: Icon(Icons.receipt_long_outlined),
        ),
      ),
      const SizedBox(height: 8),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('Effective from', style: Theme.of(context).textTheme.labelLarge),
      ),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
              value: false,
              label: Text('Next month'),
              icon: Icon(Icons.event_outlined)),
          ButtonSegment(
              value: true,
              label: Text('This month'),
              icon: Icon(Icons.today_outlined)),
        ],
        selected: {_effectiveThisMonth},
        onSelectionChanged: (s) => setState(() => _effectiveThisMonth = s.first),
      ),
      const SizedBox(height: 6),
      Text(_effectiveThisMonth ? 'Applies from $thisMonth' : 'Applies from $nextMonth',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Update rent'),
      ),
    ]);
  }
}
