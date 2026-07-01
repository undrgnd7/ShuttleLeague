enum MatchStatus { scheduled, inProgress, completed }

class ScheduledMatch {
  final int matchNumber;
  final int round;        // simultaneous round number
  final int courtNumber;
  final List<String> teamA;
  final List<String> teamB;
  MatchStatus status;
  bool? teamAWon;

  ScheduledMatch({
    required this.matchNumber,
    required this.round,
    required this.courtNumber,
    required this.teamA,
    required this.teamB,
    this.status = MatchStatus.scheduled,
    this.teamAWon,
  });

  ScheduledMatch copyWith({
    MatchStatus? status,
    bool? teamAWon,
  }) =>
      ScheduledMatch(
        matchNumber: matchNumber,
        round: round,
        courtNumber: courtNumber,
        teamA: teamA,
        teamB: teamB,
        status: status ?? this.status,
        teamAWon: teamAWon ?? this.teamAWon,
      );

  bool get isScheduled => status == MatchStatus.scheduled;
  bool get isInProgress => status == MatchStatus.inProgress;
  bool get isCompleted => status == MatchStatus.completed;

  List<String> get allPlayers => [...teamA, ...teamB];
}
