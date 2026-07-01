import 'schedule_model.dart';

class ScheduleGenerator {
  /// Generates a session schedule for [playerIds] across [courts] simultaneous courts.
  ///
  /// Each "round" runs all courts at the same time. Players rotate so that:
  /// - Everyone gets rest proportionally when players > courts × 4.
  /// - Partners change every round to maximise variety.
  /// - Teams within each court are balanced by rating (snake-draft).
  ///
  /// Rounds are calculated automatically: enough for each player to play
  /// approximately (n − 1) times, matching a full partner-rotation session.
  static List<ScheduledMatch> generate({
    required List<String> playerIds,
    required int courts,
    Map<String, int>? ratings,
  }) {
    final n = playerIds.length;
    if (n < 4) return [];

    // Never use more courts than floor(n/4)
    final activeCourts = courts.clamp(1, n ~/ 4);
    final activePerRound = activeCourts * 4;

    // Rounds needed so each player plays ≈ (n-1) times
    final rounds =
        (((n - 1) * n) / activePerRound).ceil().clamp(1, 30);

    // Sort players by rating (descending) once for stable ordering
    final byRating = List<String>.from(playerIds);
    byRating.sort(
        (a, b) => (ratings?[b] ?? 0).compareTo(ratings?[a] ?? 0));

    // Play-count tracking for fair rest rotation
    final playCounts = <String, int>{for (final id in playerIds) id: 0};
    Set<String> lastRoundActive = {};

    final matches = <ScheduledMatch>[];
    int matchNumber = 0;

    for (int round = 1; round <= rounds; round++) {
      // ── Select who plays this round ──────────────────────────────
      // Priority: 1) rested (didn't play last round), 2) fewest total plays
      final candidates = List<String>.from(byRating);
      candidates.sort((a, b) {
        final aPlayed = lastRoundActive.contains(a) ? 1 : 0;
        final bPlayed = lastRoundActive.contains(b) ? 1 : 0;
        if (aPlayed != bPlayed) return aPlayed - bPlayed; // rested first
        return playCounts[a]!.compareTo(playCounts[b]!);  // fewest plays first
      });

      final active = candidates.take(activePerRound).toList();
      lastRoundActive = active.toSet();
      for (final id in active) {
        playCounts[id] = playCounts[id]! + 1;
      }

      // ── Assign to courts ─────────────────────────────────────────
      // Sort active players by rating for balanced distribution.
      // Rotate starting position each round so partners change.
      final rated = List<String>.from(active);
      rated.sort((a, b) => (ratings?[b] ?? 0).compareTo(ratings?[a] ?? 0));

      // Interleave across courts: rank1→C1, rank2→C2, rank3→C1, ...
      // Offset by round so pairings vary each round
      final courtGroups =
          List.generate(activeCourts, (_) => <String>[]);
      for (int i = 0; i < rated.length; i++) {
        final courtIdx = ((i + (round - 1)) % activeCourts);
        courtGroups[courtIdx].add(rated[i]);
      }

      // ── Build matches ────────────────────────────────────────────
      for (int c = 0; c < activeCourts; c++) {
        final group = courtGroups[c];
        if (group.length < 4) continue;

        // Sort group by rating then snake-draft:
        // rank1 + rank4 vs rank2 + rank3 → most balanced 2v2
        group.sort(
            (a, b) => (ratings?[b] ?? 0).compareTo(ratings?[a] ?? 0));

        matchNumber++;
        matches.add(ScheduledMatch(
          matchNumber: matchNumber,
          round: round,
          courtNumber: c + 1,
          teamA: [group[0], group[3]],
          teamB: [group[1], group[2]],
        ));
      }
    }

    return matches;
  }
}
