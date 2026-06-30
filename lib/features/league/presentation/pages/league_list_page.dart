import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/league_provider.dart';
import 'create_league_page.dart';

class LeagueListPage extends ConsumerWidget {
  const LeagueListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leagueListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leagues'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateLeaguePage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: leaguesAsync.when(
        data: (leagues) {
          if (leagues.isEmpty) {
            return const Center(child: Text('No leagues yet'));
          }

          return ListView.builder(
            itemCount: leagues.length,
            itemBuilder: (context, index) {
              final league = leagues[index];

              return ListTile(
                title: Text(league.name),
                subtitle: Text('Max players: ${league.maxPlayers}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
