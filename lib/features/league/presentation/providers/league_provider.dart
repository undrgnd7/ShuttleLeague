import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_provider.dart';
import '../../../player/data/player_model.dart';
import '../../data/league_model.dart';
import '../../data/league_repository_impl.dart';
import '../../domain/league_repository.dart';

final leagueDetailPlayersProvider =
    FutureProvider.family<List<PlayerModel>, String>((ref, leagueId) {
  final db = ref.read(databaseProvider);
  final repo = LeagueRepositoryImpl(db);

  return repo.getLeaguePlayers(leagueId);
});

final leagueControllerProvider = Provider((ref) {
  final db = ref.read(databaseProvider);
  return LeagueController(LeagueRepositoryImpl(db));
});

class LeagueController {
  final LeagueRepository _repo;
  LeagueController(this._repo);

  Future<void> createLeague(String name, {int maxPlayers = 16}) async {
    final league = LeagueModel(
      id: const Uuid().v4(),
      name: name.trim(),
      maxPlayers: maxPlayers,
      createdAt: DateTime.now(),
    );
    await _repo.createLeague(league);
  }
}
