import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/league_repository_impl.dart';
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

class _AddPlayerButton extends ConsumerWidget {
  final String leagueId;

  const _AddPlayerButton({required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playerListProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.person_add),
        label: const Text('Add Player'),
        onPressed: () async {
          final players = playersAsync.valueOrNull ?? [];
          if (players.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No players available')),
            );
            return;
          }
          final selected = await showDialog<PlayerModel>(
            context: context,
            builder: (_) => _PlayerPickerDialog(players: players),
          );
          if (selected != null) {
            final db = ref.read(databaseProvider);
            await LeagueRepositoryImpl(db).addPlayerToLeague(
              leagueId: leagueId,
              player: selected,
            );
            ref.invalidate(leagueDetailPlayersProvider(leagueId));
          }
        },
      ),
    );
  }
}

class _PlayerPickerDialog extends StatelessWidget {
  final List<PlayerModel> players;

  const _PlayerPickerDialog({required this.players});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select Player'),
      children: players
          .map((p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, p),
                child: Text(p.name),
              ))
          .toList(),
    );
  }
}
