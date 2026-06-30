import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/leaderboard_provider.dart';

class LeaderboardPage extends ConsumerWidget {
  final String leagueId;

  const LeaderboardPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider(leagueId));

    return Scaffold(
      appBar: AppBar(title: const Text("Leaderboard")),
      body: leaderboard.when(
        data: (players) {
          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final p = players[index];

              return ListTile(
                leading: Text("#${index + 1}"),
                title: Text(p.name),
                subtitle: Text(
                  "Rating: ${p.rating} | W:${p.wins} L:${p.losses}",
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }
}
