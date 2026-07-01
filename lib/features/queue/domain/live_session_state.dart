class ActiveMatch {
  final String matchId;
  final int courtNumber;
  final List<String> teamA;
  final List<String> teamB;

  const ActiveMatch({
    required this.matchId,
    required this.courtNumber,
    required this.teamA,
    required this.teamB,
  });
}

class LiveSessionState {
  final String sessionId;
  final List<String> waitingQueue;
  final List<ActiveMatch> activeMatches;

  const LiveSessionState({
    required this.sessionId,
    required this.waitingQueue,
    required this.activeMatches,
  });

  LiveSessionState copyWith({
    List<String>? waitingQueue,
    List<ActiveMatch>? activeMatches,
  }) {
    return LiveSessionState(
      sessionId: sessionId,
      waitingQueue: waitingQueue ?? this.waitingQueue,
      activeMatches: activeMatches ?? this.activeMatches,
    );
  }

  // Keep for backward-compat reads
  Map<int, String> get courtAssignments => {
        for (final m in activeMatches) m.courtNumber: m.matchId,
      };
}
