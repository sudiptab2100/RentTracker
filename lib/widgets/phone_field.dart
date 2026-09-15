import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/phone_number.dart';

/// A phone input with a country-code dropdown (default +91) and a 10-digit
/// number field, with optional "pick from contacts". Reports changes via
/// [onChanged]; validates to exactly 10 digits within an enclosing [Form].
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.label,
    required this.icon,
    required this.initial,
    required this.onChanged,
    this.onPickContact,
    this.requiredField = false,
  });

  final String label;
  final IconData icon;
  final PhoneNumber initial;
  final ValueChanged<PhoneNumber> onChanged;

  /// When provided, shows a contacts button that returns a raw number string.
  final Future<String?> Function()? onPickContact;
  final bool requiredField;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late String _cc =
      widget.initial.countryCode.isEmpty ? '+91' : widget.initial.countryCode;
  late final TextEditingController _num =
      TextEditingController(text: widget.initial.number);

  @override
  void dispose() {
    _num.dispose();
    super.dispose();
  }

  void _emit() =>
      widget.onChanged(PhoneNumber(countryCode: _cc, number: _num.text.trim()));

  String? _validate(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return widget.requiredField ? '${widget.label} is required' : null;
    if (digits.length != 10) return 'Enter a 10-digit number';
    return null;
  }

  Future<void> _pick() async {
    final raw = await widget.onPickContact?.call();
    if (raw == null) return;
    final parsed = PhoneNumber.fromLegacy(raw);
    setState(() {
      _cc = parsed.countryCode;
      _num.text = parsed.number;
    });
    _emit();
  }

  // Ensure the current code is present in the list (custom legacy codes).
  List<String> get _codes {
    final codes = kCountryCodes.map((c) => c.dial).toList();
    if (!codes.contains(_cc)) codes.insert(0, _cc);
    return codes;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: DropdownButtonFormField<String>(
            initialValue: _cc,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Code'),
            selectedItemBuilder: (context) =>
                _codes.map((d) => Align(alignment: Alignment.centerLeft, child: Text(d))).toList(),
            items: [
              for (final c in kCountryCodes)
                DropdownMenuItem(
                  value: c.dial,
                  child: Text('${c.dial}  ${c.name}', overflow: TextOverflow.ellipsis),
                ),
              if (!kCountryCodes.any((c) => c.dial == _cc))
                DropdownMenuItem(value: _cc, child: Text(_cc)),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _cc = v);
                _emit();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _num,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(widget.icon),
              suffixIcon: widget.onPickContact != null
                  ? IconButton(
                      tooltip: 'Pick from contacts',
                      icon: const Icon(Icons.contacts_outlined),
                      onPressed: _pick,
                    )
                  : null,
            ),
            validator: _validate,
            onChanged: (_) => _emit(),
          ),
        ),
      ],
    );
  }
}
