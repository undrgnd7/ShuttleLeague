import 'package:go_router/go_router.dart';

import '../features/splash/presentation/pages/splash_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/league/presentation/pages/league_list_page.dart';
import '../features/attendance/presentation/pages/qr_scan_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: '/leagues',
        builder: (_, __) => const LeagueListPage(),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, __) => QRScanPage(
          onScanned: (data) {
            // parse QR → leagueId|sessionId|playerId
          },
        ),
      ),
    ],
  );
}
