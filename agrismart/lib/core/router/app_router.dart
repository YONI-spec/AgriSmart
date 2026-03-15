// lib/core/router/app_router.dart
// Navigation AgriSmart — 2 branches (Accueil + Historique)
// Scanner accessible via FAB uniquement (hors StatefulShellRoute)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_names.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/scanner/scanner_screen.dart';
import '../../presentation/result/result_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/profil/profil_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: false,
    routes: [

      // ── Splash (hors shell) ──────────────────────────────────
      GoRoute(
        path: RouteNames.splash,
        name: RouteNames.splashName,
        pageBuilder: (context, state) => _fadeTransition(
          state, const SplashScreen(),
        ),
      ),

      // ── Scanner + Résultat (hors shell — lancés via FAB) ─────
      GoRoute(
        path: RouteNames.scanner,
        name: RouteNames.scannerName,
        pageBuilder: (context, state) => _fadeTransition(
          state, const ScannerScreen(),
        ),
        routes: [
          GoRoute(
            path: 'result',
            name: RouteNames.resultName,
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return _slideUpTransition(state, ResultScreen(data: extra));
            },
          ),
        ],
      ),

      // ── Shell avec bottom nav + FAB ──────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [

          // Branche 0 — Accueil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: RouteNames.homeName,
                pageBuilder: (context, state) => _slideTransition(
                  state, const HomeScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'profil',
                    name: RouteNames.profilName,
                    pageBuilder: (context, state) => _slideTransition(
                      state, const ProfilScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: RouteNames.settingsName,
                    pageBuilder: (context, state) => _slideTransition(
                      state, const SettingsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branche 1 — Historique des scans
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.history,
                name: RouteNames.historyName,
                pageBuilder: (context, state) => _slideTransition(
                  state, const HistoryScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ── Transitions ───────────────────────────────────────────────────

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        ),
  );
}

CustomTransitionPage<void> _slideTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(0.06, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

CustomTransitionPage<void> _slideUpTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: CurveTween(curve: Curves.easeOut).animate(animation),
          child: child,
        ),
      );
    },
  );
}