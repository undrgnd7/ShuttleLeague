import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class ShuttleLeagueApp extends StatelessWidget {
  const ShuttleLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ShuttleLeague',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
