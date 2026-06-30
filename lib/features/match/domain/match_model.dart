class MatchModel {
  final String id;
  final String leagueId;
  final String sessionId;

  final List<String> teamA;
  final List<String> teamB;

  final DateTime createdAt;

  MatchModel({
    required this.id,
    required this.leagueId,
    required this.sessionId,
    required this.teamA,
    required this.teamB,
    required this.createdAt,
  });
}
