import '../match_model.dart';

abstract class MatchRepository {
  Future<List<MatchModel>> getMatches(String sessionId);

  Future<void> generateMatches({
    required String leagueId,
    required String sessionId,
    required List<String> playerIds,
  });
}
