enum MatchStatus { scheduled, inProgress, completed }

class ScheduledMatch {
  final int matchNumber;
  final int round;
  final int courtNumber;
  final List<String> teamA;
  final List<String> teamB;
  MatchStatus status;
  bool? teamAWon;
  int? scoreA;
  int? scoreB;

  ScheduledMatch({
    required this.matchNumber,
    required this.round,
    required this.courtNumber,
    required this.teamA,
    required this.teamB,
    this.status = MatchStatus.scheduled,
    this.teamAWon,
    this.scoreA,
    this.scoreB,
  });

  ScheduledMatch copyWith({
    MatchStatus? status,
    bool? teamAWon,
    int? scoreA,
    int? scoreB,
  }) =>
      ScheduledMatch(
        matchNumber: matchNumber,
        round: round,
        courtNumber: courtNumber,
        teamA: teamA,
        teamB: teamB,
        status: status ?? this.status,
        teamAWon: teamAWon ?? this.teamAWon,
        scoreA: scoreA ?? this.scoreA,
        scoreB: scoreB ?? this.scoreB,
      );

  bool get isScheduled => status == MatchStatus.scheduled;
  bool get isInProgress => status == MatchStatus.inProgress;
  bool get isCompleted => status == MatchStatus.completed;

  List<String> get allPlayers => [...teamA, ...teamB];

  Map<String, dynamic> toMap() => {
        'matchNumber': matchNumber,
        'round': round,
        'courtNumber': courtNumber,
        'teamA': teamA,
        'teamB': teamB,
        'status': status.name,
        if (teamAWon != null) 'teamAWon': teamAWon,
        if (scoreA != null) 'scoreA': scoreA,
        if (scoreB != null) 'scoreB': scoreB,
      };

  factory ScheduledMatch.fromMap(Map<String, dynamic> map) => ScheduledMatch(
        matchNumber: (map['matchNumber'] as num).toInt(),
        round: (map['round'] as num).toInt(),
        courtNumber: (map['courtNumber'] as num).toInt(),
        teamA: List<String>.from(map['teamA'] as List),
        teamB: List<String>.from(map['teamB'] as List),
        status: MatchStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => MatchStatus.scheduled,
        ),
        teamAWon: map['teamAWon'] as bool?,
        scoreA: (map['scoreA'] as num?)?.toInt(),
        scoreB: (map['scoreB'] as num?)?.toInt(),
      );
}
