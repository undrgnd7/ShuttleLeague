import 'schedule_model.dart';

class ScheduleGenerator {
  /// Generates a session schedule for [playerIds] across [courts] simultaneous courts.
  ///
  /// Each round runs [courts] matches at the same time. The algorithm greedily
  /// selects groups and pairings that maximise unique partnerships — so everyone
  /// rotates partners across rounds rather than repeating the same matches.
  static List<ScheduledMatch> generate({
    required List<String> playerIds,
    required int courts,
    Map<String, int>? ratings,
  }) {
    final n = playerIds.length;
    if (n < 4) return [];

    final activeCourts = courts.clamp(1, n ~/ 4);
    final activePerRound = activeCourts * 4;

    // Rounds needed so each player gets to partner with every other player once.
    // Each player needs (n-1) matches; they play in activePerRound/n fraction of rounds.
    final rounds =
        ((n * (n - 1)) / activePerRound).ceil().clamp(3, 30);

    // Track how many rounds each player has played.
    final playCounts = List.filled(n, 0);

    // partnerCount[i][j] = times i and j have been teammates.
    final partnerCount = List.generate(n, (_) => List.filled(n, 0));

    final ratingOf = (int i) => ratings?[playerIds[i]] ?? 0;

    final matches = <ScheduledMatch>[];
    int matchNumber = 0;

    for (int round = 1; round <= rounds; round++) {
      final usedThisRound = <int>{};

      for (int c = 0; c < activeCourts; c++) {
        // Available players not yet assigned this round, sorted by fewest plays first,
        // then by index as a stable tiebreak so the order is deterministic.
        final avail = [
          for (int i = 0; i < n; i++)
            if (!usedThisRound.contains(i)) i,
        ]..sort((a, b) {
            final d = playCounts[a].compareTo(playCounts[b]);
            return d != 0 ? d : a.compareTo(b);
          });

        if (avail.length < 4) break;

        // Pick the 4-player group that minimises total prior-partnership count
        // (i.e. puts together players who have played together the fewest times).
        final group = _pickGroup(avail, partnerCount);
        usedThisRound.addAll(group);

        // Sort the group by rating (desc), tiebreak by index, for snake-draft.
        final ranked = List<int>.from(group)
          ..sort((a, b) {
            final d = ratingOf(b).compareTo(ratingOf(a));
            return d != 0 ? d : a.compareTo(b);
          });

        // Three possible 2v2 splits for ranked [r0,r1,r2,r3]:
        //   A (snake): [r0,r3] vs [r1,r2]   ← most balanced by rating
        //   B:         [r0,r2] vs [r1,r3]
        //   C:         [r0,r1] vs [r2,r3]
        // Pick the split whose two partnerships are least repeated.
        final r0 = ranked[0], r1 = ranked[1], r2 = ranked[2], r3 = ranked[3];
        final options = [
          [
            [r0, r3],
            [r1, r2],
          ],
          [
            [r0, r2],
            [r1, r3],
          ],
          [
            [r0, r1],
            [r2, r3],
          ],
        ];

        int minScore = 999999;
        var bestOpt = options[0];
        for (final opt in options) {
          final score =
              partnerCount[opt[0][0]][opt[0][1]] + partnerCount[opt[1][0]][opt[1][1]];
          if (score < minScore) {
            minScore = score;
            bestOpt = opt;
          }
        }

        // Record the chosen partnerships.
        partnerCount[bestOpt[0][0]][bestOpt[0][1]]++;
        partnerCount[bestOpt[0][1]][bestOpt[0][0]]++;
        partnerCount[bestOpt[1][0]][bestOpt[1][1]]++;
        partnerCount[bestOpt[1][1]][bestOpt[1][0]]++;

        for (final p in group) playCounts[p]++;

        matchNumber++;
        matches.add(ScheduledMatch(
          matchNumber: matchNumber,
          round: round,
          courtNumber: c + 1,
          teamA: bestOpt[0].map((i) => playerIds[i]).toList(),
          teamB: bestOpt[1].map((i) => playerIds[i]).toList(),
        ));
      }
    }

    return matches;
  }

  /// From [avail] (sorted, least-played first), pick 4 players whose combined
  /// prior-partnership count is minimal — maximising new partnerships this match.
  static List<int> _pickGroup(List<int> avail, List<List<int>> partnerCount) {
    if (avail.length <= 4) return avail.take(4).toList();

    // Always anchor on the first player (least played) and search for the best
    // 3 companions from the rest.
    final anchor = avail[0];
    final rest = avail.skip(1).toList();

    int bestScore = 999999;
    var best = [anchor, rest[0], rest[1], rest[2]];

    // Try every C(rest.length, 3) combination — fast for typical n ≤ 24.
    for (int i = 0; i < rest.length - 2; i++) {
      for (int j = i + 1; j < rest.length - 1; j++) {
        for (int k = j + 1; k < rest.length; k++) {
          final g = [anchor, rest[i], rest[j], rest[k]];
          // Sum all 6 pairwise partner-counts within this group of 4.
          final score = partnerCount[g[0]][g[1]] +
              partnerCount[g[0]][g[2]] +
              partnerCount[g[0]][g[3]] +
              partnerCount[g[1]][g[2]] +
              partnerCount[g[1]][g[3]] +
              partnerCount[g[2]][g[3]];
          if (score < bestScore) {
            bestScore = score;
            best = g;
            if (score == 0) break; // can't do better
          }
        }
        if (bestScore == 0) break;
      }
      if (bestScore == 0) break;
    }

    return best;
  }
}
