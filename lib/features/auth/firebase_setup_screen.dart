import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';

/// Shown when [firebase_options.dart] still contains placeholder values,
/// guiding the user through connecting their own Firebase project.
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  static const _steps = [
    'Create a Firebase project at console.firebase.google.com',
    'Enable Authentication → Email/Password, Google and Phone providers',
    'Create a Cloud Firestore database (production mode)',
    'Install the CLIs: dart pub global activate flutterfire_cli',
    'From the project folder run: flutterfire configure',
    'For Google Sign-In, paste your Web client ID into lib/core/app_config.dart',
    'Rebuild and run the app',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('${AppConfig.appName} · Setup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.local_fire_department, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Connect Firebase to get started', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'This app needs your own Firebase project for authentication and the '
            'database. Follow these steps, then restart the app.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ...List.generate(_steps.length, (i) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
              title: Text(_steps[i]),
            );
          }),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 18),
                      const SizedBox(width: 8),
                      Text('Quick command', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => Clipboard.setData(
                          const ClipboardData(text: 'flutterfire configure'),
                        ),
                      ),
                    ],
                  ),
                  const SelectableText('flutterfire configure'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('See SETUP.md in the project for full details.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
