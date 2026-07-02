import '../../player/data/player_model.dart';
import 'elo_engine.dart';

class MatchResultProcessor {
  /// Update ratings after a match
  static void process({
    required List<PlayerModel> teamA,
    required List<PlayerModel> teamB,
    required bool teamAWon,
  }) {
    for (final p in teamA) {
      EloEngine.calculateNewRating(
        rating: p.rating,
        opponentRating: _avg(teamB),
        won: teamAWon,
      );

      // update logic will be handled in repository
    }

    for (final p in teamB) {
      EloEngine.calculateNewRating(
        rating: p.rating,
        opponentRating: _avg(teamA),
        won: !teamAWon,
      );

      // update logic will be handled in repository
    }
  }

  static int _avg(List<PlayerModel> players) {
    if (players.isEmpty) return 1000;

    final sum = players.fold<int>(0, (a, b) => a + b.rating);
    return (sum / players.length).round();
  }
}
