import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../widgets/ui_helpers.dart';

/// Opens the device's native contact picker and returns the selected phone
/// number (or null if cancelled). Lets the owner add WhatsApp / emergency
/// numbers "from saved contacts".
Future<String?> pickContactPhone(BuildContext context) async {
  Contact? contact;
  try {
    contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
  } catch (e) {
    if (context.mounted) {
      showSnack(context, 'Could not open contacts: $e', isError: true);
    }
    return null;
  }

  if (contact == null) return null; // cancelled
  final phones = contact.phones;
  if (phones.isEmpty) {
    if (context.mounted) {
      showSnack(context, 'That contact has no phone number', isError: true);
    }
    return null;
  }
  if (phones.length == 1) return phones.first.number;

  if (!context.mounted) return null;
  final selected = contact;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(selected.displayName ?? 'Choose a number'),
            subtitle: const Text('Select which number to use'),
          ),
          const Divider(height: 0),
          ...phones.map(
            (p) => ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(p.number),
              onTap: () => Navigator.pop(context, p.number),
            ),
          ),
        ],
      ),
    ),
  );
}
