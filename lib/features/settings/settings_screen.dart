import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../services/firebase_providers.dart';
import '../../widgets/ui_helpers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.displayName?.isNotEmpty == true
                ? user!.displayName!
                : 'Owner'),
            subtitle: Text(user?.email ?? user?.phoneNumber ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Data export & import'),
            subtitle: const Text('Master backup, migration and CSV exports'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/data'),
          ),
          const Divider(),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: AppConfig.appName,
            applicationVersion: '1.0.0',
            aboutBoxChildren: const [
              Text('Lightweight rent tracking for flat owners, powered by Firebase.'),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFC62828)),
            title: const Text('Sign out', style: TextStyle(color: Color(0xFFC62828))),
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in again to access your data.',
                confirmLabel: 'Sign out',
                destructive: false,
              );
              if (ok) {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
