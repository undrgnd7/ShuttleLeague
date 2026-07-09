import '../../player/data/player_model.dart';
import '../data/league_model.dart';

abstract class LeagueRepository {
  Future<List<LeagueModel>> getLeagues();
  Future<void> createLeague(LeagueModel league);
  Future<void> updateLeague(LeagueModel league);
  Future<void> deleteLeague(String id);
  Future<bool> isNameTaken(String name);

  Future<void> addPlayerToLeague({
    required String leagueId,
    required PlayerModel player,
  });

  Future<List<PlayerModel>> getLeaguePlayers(String leagueId);
}
