class SessionSummary {
  final String id;
  final String leagueId;
  final String status;
  final DateTime? createdAt;
  final int matchCount;
  final int completedCount;

  SessionSummary({
    required this.id,
    required this.leagueId,
    required this.status,
    required this.createdAt,
    required this.matchCount,
    required this.completedCount,
  });

  bool get isActive => status == 'active';
}
