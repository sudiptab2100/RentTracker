import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../features/auth/firebase_setup_screen.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_controller.dart';

class RentTrackerApp extends ConsumerWidget {
  const RentTrackerApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    if (!firebaseReady) {
      return MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: const FirebaseSetupScreen(),
      );
    }
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
