import 'package:go_router/go_router.dart';
import '../../shell/app_shell.dart';
import '../../pages/connection_page.dart';
import '../../pages/fly_view/fly_view.dart';
import '../../pages/mission_page.dart';
import '../../pages/simulation_page.dart';
import '../../pages/vehicles_page.dart';
import '../../pages/telemetry_page.dart';
import '../../pages/alerts_page.dart';
import '../../pages/parameters_page.dart';
import '../../pages/video_page.dart';
import '../../pages/diagnostics_page.dart';
import '../../pages/logs_page.dart';
import '../../pages/settings_page.dart';

final appRouter = GoRouter(
  initialLocation: '/connect',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/connect', builder: (_, __) => const ConnectionPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/fly', builder: (_, __) => const FlyView()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/mission', builder: (_, __) => const MissionPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/simulation', builder: (_, __) => const SimulationPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/vehicles', builder: (_, __) => const VehiclesPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/telemetry', builder: (_, __) => const TelemetryPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/parameters', builder: (_, __) => const ParametersPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/video', builder: (_, __) => const VideoPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/diagnostics',
              builder: (_, __) => const DiagnosticsPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/logs', builder: (_, __) => const LogsPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ]),
      ],
    ),
  ],
);
