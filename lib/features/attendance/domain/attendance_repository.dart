abstract class AttendanceRepository {
  Future<String> createSession(String leagueId);

  Future<void> checkIn({
    required String sessionId,
    required String leagueId,
    required String playerId,
  });

  Future<List<String>> getCheckedInPlayers(String sessionId);
}
