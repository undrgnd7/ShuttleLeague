import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/league_repository_impl.dart';
import '../../data/league_model.dart';
import '../../domain/league_repository.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  final db = ref.read(databaseProvider);
  return LeagueRepositoryImpl(db);
});

final leagueListProvider = FutureProvider((ref) async {
  final repo = ref.read(leagueRepositoryProvider);
  return repo.getLeagues();
});

final leagueControllerProvider = Provider((ref) {
  final repo = ref.read(leagueRepositoryProvider);

  return LeagueController(repo, ref);
});

class LeagueController {
  final LeagueRepository repo;
  final Ref ref;

  LeagueController(this.repo, this.ref);

  Future<void> createLeague(String name) async {
    final league = LeagueModel(
      id: const Uuid().v4(),
      name: name,
      maxPlayers: 16,
      createdAt: DateTime.now(),
    );

    await repo.createLeague(league);
    ref.invalidate(leagueListProvider);
  }
}
