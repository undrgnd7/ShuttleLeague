import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/data/player_model.dart';
import '../providers/league_detail_provider.dart';
import '../providers/league_provider.dart';

class LeagueDetailPage extends ConsumerWidget {
  final String leagueId;
  final String leagueName;

  const LeagueDetailPage({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(leagueDetailPlayersProvider(leagueId));

    return Scaffold(
      appBar: AppBar(title: Text(leagueName)),
      body: playersAsync.when(
        data: (players) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('Skill: ${p.skillLevel}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _AddPlayerButton(leagueId: leagueId),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
