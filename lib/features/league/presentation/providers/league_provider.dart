import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/firebase/firebase_provider.dart';
import '../../../player/data/player_model.dart';
import '../../data/league_model.dart';
import '../../data/league_cloud_repository.dart';
import '../../domain/league_repository.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  final db = ref.read(firestoreProvider);
  return LeagueCloudRepository(db);
});

final leagueDetailPlayersProvider =
    FutureProvider.family<List<PlayerModel>, String>((ref, leagueId) {
  final db = ref.read(firestoreProvider);
  return LeagueCloudRepository(db).getLeaguePlayers(leagueId);
});

final leagueControllerProvider = Provider((ref) {
  return LeagueController(ref.read(leagueRepositoryProvider));
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

  Future<void> updateLeague(LeagueModel league) => _repo.updateLeague(league);

  Future<void> deleteLeague(String id) => _repo.deleteLeague(id);
}
