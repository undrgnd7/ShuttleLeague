import 'package:go_router/go_router.dart';

import '../features/about/presentation/pages/about_page.dart';
import '../features/attendance/presentation/pages/qr_scan_page.dart';
import '../features/auth/presentation/pages/account_page.dart';
import '../features/auth/presentation/pages/user_management_page.dart';
import '../features/session/presentation/pages/player_session_page.dart';
import '../features/attendance/presentation/pages/qr_session_page.dart';
import '../features/attendance/presentation/pages/scan_hub_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/leaderboard/presentation/pages/leaderboard_page.dart';
import '../features/league/data/league_model.dart';
import '../features/league/presentation/pages/create_league_page.dart';
import '../features/player/data/player_model.dart';
import '../features/league/presentation/pages/league_detail_page.dart';
import '../features/league/presentation/pages/league_list_page.dart';
import '../features/player/presentation/pages/create_player_page.dart';
import '../features/player/presentation/pages/my_match_history_page.dart';
import '../features/player/presentation/pages/player_list_page.dart';
import '../features/player/presentation/pages/player_profile_page.dart';
import '../features/schedule/presentation/pages/schedule_page.dart';
import '../features/session/presentation/pages/session_dashboard.dart';
import '../features/session/presentation/pages/session_detail_page.dart';
import '../features/session/presentation/pages/session_history_page.dart';
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
      GoRoute(
        path: '/account',
        builder: (_, __) => const AccountPage(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const UserManagementPage(),
      ),
      GoRoute(
        path: '/about',
        builder: (_, __) => const AboutPage(),
      ),
      GoRoute(
        path: '/me/history',
        builder: (_, __) => const MyMatchHistoryPage(),
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
          GoRoute(
            path: '/leaderboard',
            builder: (_, __) => const LeaderboardPage(leagueId: ''),
          ),
        ],
      ),

      // Detail routes — no bottom nav
      GoRoute(
        path: '/players/create',
        builder: (_, __) => const CreatePlayerPage(),
      ),
      GoRoute(
        path: '/players/:id/edit',
        builder: (_, state) =>
            CreatePlayerPage(player: state.extra as PlayerModel?),
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
        path: '/leagues/:id/edit',
        builder: (_, state) =>
            CreateLeaguePage(league: state.extra as LeagueModel?),
      ),
      GoRoute(
        path: '/leagues/:id',
        builder: (_, state) {
          final league = state.extra as LeagueModel?;
          return LeagueDetailPage(
            leagueId: state.pathParameters['id']!,
            leagueName: league?.name ?? state.uri.queryParameters['name'] ?? 'League',
            league: league,
          );
        },
      ),
      GoRoute(
        path: '/leagues/:id/leaderboard',
        builder: (_, state) =>
            LeaderboardPage(leagueId: state.pathParameters['id']!),
      ),
      GoRoute(
        // sessionId is a path segment (not `extra`) so the route survives a
        // browser refresh/direct link on web — `extra` is in-memory only
        // and is lost on reload, which used to silently fall back to a
        // shared 'default' session id.
        path: '/leagues/:id/session/:sessionId',
        builder: (_, state) => SessionDashboard(
          leagueId: state.pathParameters['id']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/leagues/:id/qr',
        builder: (_, state) =>
            QRSessionPage(leagueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leagues/:id/schedule/:sessionId',
        builder: (_, state) => SchedulePage(
          leagueId: state.pathParameters['id']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/leagues/:id/session/:sessionId/view',
        builder: (_, state) => PlayerSessionPage(
          sessionId: state.pathParameters['sessionId']!,
          leagueName: state.uri.queryParameters['leagueName'] ?? 'League',
        ),
      ),
      GoRoute(
        path: '/leagues/:id/sessions',
        builder: (_, state) => SessionHistoryPage(
          leagueId: state.pathParameters['id']!,
          leagueName: (state.extra as String?) ?? 'League',
        ),
      ),
      GoRoute(
        path: '/leagues/:id/sessions/:sessionId',
        builder: (_, state) => SessionDetailPage(
          leagueId: state.pathParameters['id']!,
          sessionId: state.pathParameters['sessionId']!,
          leagueName: (state.extra as String?) ?? 'League',
        ),
      ),
      GoRoute(
        path: '/scan/camera',
        builder: (_, __) => QRScanPage(onScanned: (_) {}),
      ),
    ],
  );
}
