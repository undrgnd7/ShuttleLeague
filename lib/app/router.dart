import 'package:go_router/go_router.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/league/presentation/pages/league_list_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/leagues',
        builder: (context, state) => const LeagueListPage(),
      ),
    ],
  );
}
