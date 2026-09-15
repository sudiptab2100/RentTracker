import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../app/theme_controller.dart';
import '../../services/firebase_providers.dart';
import '../../widgets/ui_helpers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.brightness_6_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).setMode(s.first),
            ),
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
