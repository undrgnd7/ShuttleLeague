import 'package:go_router/go_router.dart';

import '../features/attendance/presentation/pages/qr_scan_page.dart';
import '../features/attendance/presentation/pages/qr_session_page.dart';
import '../features/attendance/presentation/pages/scan_hub_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/leaderboard/presentation/pages/leaderboard_page.dart';
import '../features/league/presentation/pages/create_league_page.dart';
import '../features/league/presentation/pages/league_detail_page.dart';
import '../features/league/presentation/pages/league_list_page.dart';
import '../features/player/presentation/pages/create_player_page.dart';
import '../features/player/presentation/pages/player_list_page.dart';
import '../features/player/presentation/pages/player_profile_page.dart';
import '../features/queue/presentation/pages/queue_page.dart';
import '../features/schedule/presentation/pages/schedule_page.dart';
import '../features/session/presentation/pages/session_dashboard.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import 'app.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash — outside shell, no bottom nav
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashPage(),
      ),

      // Main shell — shows bottom navigation bar
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomePage(),
          ),
          GoRoute(
            path: '/players',
            builder: (_, __) => const PlayerListPage(),
          ),
          GoRoute(
            path: '/leagues',
            builder: (_, __) => const LeagueListPage(),
          ),
          GoRoute(
            path: '/scan',
            builder: (_, __) => const ScanHubPage(),
          ),
        ],
      ),

      // Detail routes — no bottom nav
      GoRoute(
        path: '/players/create',
        builder: (_, __) => const CreatePlayerPage(),
      ),
      GoRoute(
        path: '/players/:id',
        builder: (_, state) =>
            PlayerProfilePage(playerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leagues/create',
        builder: (_, __) => const CreateLeaguePage(),
      ),
      GoRoute(
        path: '/leagues/:id',
        builder: (_, state) => LeagueDetailPage(
          leagueId: state.pathParameters['id']!,
          leagueName: state.uri.queryParameters['name'] ?? 'League',
        ),
      ),
      GoRoute(
        path: '/leagues/:id/leaderboard',
        builder: (_, state) =>
            LeaderboardPage(leagueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leagues/:id/queue',
        builder: (_, state) => QueuePage(
          leagueId: state.pathParameters['id']!,
          sessionId: (state.extra as String?) ?? 'default',
        ),
      ),
      GoRoute(
        path: '/leagues/:id/session',
        builder: (_, state) => SessionDashboard(
          leagueId: state.pathParameters['id']!,
          sessionId: (state.extra as String?) ?? 'default',
        ),
      ),
      GoRoute(
        path: '/leagues/:id/qr',
        builder: (_, state) =>
            QRSessionPage(leagueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leagues/:id/schedule',
        builder: (_, state) => SchedulePage(
          leagueId: state.pathParameters['id']!,
          sessionId: (state.extra as String?) ?? 'default',
        ),
      ),
      GoRoute(
        path: '/scan/camera',
        builder: (_, __) => QRScanPage(onScanned: (_) {}),
      ),
    ],
  );
}
