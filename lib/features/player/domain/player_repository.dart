import '../data/player_model.dart';

abstract class PlayerRepository {
  Future<List<PlayerModel>> getPlayers();
  Future<PlayerModel?> getPlayer(String id);
  Future<void> addPlayer(PlayerModel player);
  Future<void> updatePlayer(PlayerModel player);
  Future<void> deletePlayer(String id);
  Future<bool> isNameTaken(String name);
  Future<void> recordMatchResult({
    required String leagueId,
    required List<String> winnerIds,
    required List<String> loserIds,
  });
  /// Reverse the existing result and apply the opposite.
  /// oldWinnerIds become the losers, oldLoserIds become the winners.
  Future<void> editMatchResult({
    required String leagueId,
    required List<String> oldWinnerIds,
    required List<String> oldLoserIds,
  });
}
