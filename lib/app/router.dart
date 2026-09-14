import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/apartments/apartment_detail_screen.dart';
import '../features/apartments/apartments_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/phone_login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/floors/floors_screen.dart';
import '../features/reports/report_screen.dart';
import '../features/settings/data_transfer_screen.dart';
import '../features/settings/settings_screen.dart';
import '../services/firebase_providers.dart';

/// Bridges a [Stream] to a [Listenable] so GoRouter re-evaluates redirects when
/// the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

const _authRoutes = {'/login', '/register', '/phone', '/forgot'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable:
        GoRouterRefreshStream(ref.watch(firebaseAuthProvider).authStateChanges()),
    redirect: (context, state) {
      final loggedIn = ref.read(firebaseAuthProvider).currentUser != null;
      final loggingIn = _authRoutes.contains(state.matchedLocation);
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/phone', builder: (c, s) => const PhoneLoginScreen()),
      GoRoute(path: '/forgot', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/settings/data', builder: (c, s) => const DataTransferScreen()),
      GoRoute(
        path: '/building/:bid',
        builder: (c, s) => FloorsScreen(buildingId: s.pathParameters['bid']!),
      ),
      GoRoute(
        path: '/building/:bid/floor/:fid',
        builder: (c, s) => ApartmentsScreen(
          buildingId: s.pathParameters['bid']!,
          floorId: s.pathParameters['fid']!,
        ),
      ),
      GoRoute(
        path: '/building/:bid/floor/:fid/apt/:aid',
        builder: (c, s) => ApartmentDetailScreen(
          buildingId: s.pathParameters['bid']!,
          floorId: s.pathParameters['fid']!,
          apartmentId: s.pathParameters['aid']!,
        ),
      ),
      GoRoute(
        path: '/building/:bid/floor/:fid/apt/:aid/report/:month',
        builder: (c, s) => ReportScreen(
          buildingId: s.pathParameters['bid']!,
          floorId: s.pathParameters['fid']!,
          apartmentId: s.pathParameters['aid']!,
          month: s.pathParameters['month']!,
        ),
      ),
    ],
  );
});
