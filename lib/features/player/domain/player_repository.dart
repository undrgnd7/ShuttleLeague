import '../data/player_model.dart';

abstract class PlayerRepository {
  Future<List<PlayerModel>> getPlayers();
  Future<void> addPlayer(PlayerModel player);
}
