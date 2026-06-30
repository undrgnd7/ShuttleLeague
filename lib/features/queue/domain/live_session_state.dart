class LiveSessionState {
  final String sessionId;

  final List<String> waitingQueue;
  final String? activeMatchId;

  final Map<int, String> courtAssignments;

  LiveSessionState({
    required this.sessionId,
    required this.waitingQueue,
    required this.activeMatchId,
    required this.courtAssignments,
  });

  LiveSessionState copyWith({
    List<String>? waitingQueue,
    String? activeMatchId,
    Map<int, String>? courtAssignments,
  }) {
    return LiveSessionState(
      sessionId: sessionId,
      waitingQueue: waitingQueue ?? this.waitingQueue,
      activeMatchId: activeMatchId ?? this.activeMatchId,
      courtAssignments: courtAssignments ?? this.courtAssignments,
    );
  }
}
