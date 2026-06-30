import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/match_provider.dart';

class MatchPage extends ConsumerWidget {
  final String sessionId;

  const MatchPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Matches")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final matchRepo = ref.read(matchRepositoryProvider);

            // For now demo: static players
            await matchRepo.generateMatches(
              leagueId: "demo",
              sessionId: sessionId,
              playerIds: List.generate(8, (i) => "player_$i"),
            );
          },
          child: const Text("Generate Matches"),
        ),
      ),
    );
  }
}
