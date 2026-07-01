import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/league_model.dart';
import '../../data/league_repository_impl.dart';
import 'create_league_page.dart';
import 'league_detail_page.dart';

final leagueListProvider = FutureProvider<List<LeagueModel>>((ref) {
  final db = ref.read(databaseProvider);
  return LeagueRepositoryImpl(db).getLeagues();
});

class LeagueListPage extends ConsumerWidget {
  const LeagueListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leagueListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leagues')),
      body: leaguesAsync.when(
        data: (leagues) {
          if (leagues.isEmpty) {
            return const Center(child: Text('No leagues yet. Create one!'));
          }
          return ListView.builder(
            itemCount: leagues.length,
            itemBuilder: (context, index) {
              final league = leagues[index];
              return ListTile(
                title: Text(league.name),
                subtitle: Text('Max players: ${league.maxPlayers}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeagueDetailPage(
                        leagueId: league.id,
                        leagueName: league.name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateLeaguePage()),
          );
          ref.invalidate(leagueListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
