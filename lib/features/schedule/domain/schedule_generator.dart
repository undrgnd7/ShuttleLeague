import 'schedule_model.dart';

class ScheduleGenerator {
  /// Generates a session schedule for [playerIds] across [courts] simultaneous courts.
  ///
  /// When [genders] is provided (playerId → 'male'|'female'), female players are
  /// always paired with a male partner (mixed doubles) — never alone. Mixed
  /// pairs only face other mixed pairs. If a round has an odd number of
  /// available females, the lowest-priority female sits out that court slot.
  ///
  /// Mixed groups are not forced whenever possible: men's-only doubles are
  /// also scheduled, with the mixed/men's-only split chosen each court so that
  /// females' average game count stays in step with males' average game
  /// count — keeping total games per player as equal as possible overall.
  static List<ScheduledMatch> generate({
    required List<String> playerIds,
    required int courts,
    Map<String, int>? ratings,
    Map<String, String>? genders,
  }) {
    final n = playerIds.length;
    if (n < 4) return [];

    // Index-based gender flag: isFemale[i] == true if playerIds[i] is female.
    final isFemale = genders != null
        ? [for (int i = 0; i < n; i++) genders[playerIds[i]] == 'female']
        : null;

    final activeCourts = courts.clamp(1, n ~/ 4);
    final activePerRound = activeCourts * 4;

    // Quadratic in n so bigger sessions scale up fast (e.g. 8 players / 1
    // court → 14 rounds; 16 players / 2 courts → 30 rounds). Upper bound is
    // a safety net, not a target — it only kicks in for very large groups.
    final rounds =
        ((n * (n - 1)) / activePerRound).ceil().clamp(3, 60);

    final playCounts = List.filled(n, 0);
    final partnerCount = List.generate(n, (_) => List.filled(n, 0));

    int ratingOf(int i) => ratings?[playerIds[i]] ?? 0;

    final matches = <ScheduledMatch>[];
    int matchNumber = 0;

    for (int round = 1; round <= rounds; round++) {
      final usedThisRound = <int>{};

      for (int c = 0; c < activeCourts; c++) {
        // Available players not yet assigned this round, sorted by fewest plays
        // first, then by index as a stable tiebreak.
        final avail = [
          for (int i = 0; i < n; i++)
            if (!usedThisRound.contains(i)) i,
        ]..sort((a, b) {
            final d = playCounts[a].compareTo(playCounts[b]);
            return d != 0 ? d : a.compareTo(b);
          });

        // Gender-aware: ensure an even number of females in candidates so
        // every female can be paired with another female's male partner.
        List<int> candidates = avail;
        if (isFemale != null) {
          final femalesInAvail = avail.where((i) => isFemale[i]).toList();
          if (femalesInAvail.length % 2 == 1) {
            // Remove the most-played female (last in play-count order) so she
            // sits out this court slot and plays in the next available one.
            final sittingOut = femalesInAvail.last;
            candidates = avail.where((i) => i != sittingOut).toList();
          }
        }

        if (candidates.length < 4) break;

        // Decide whether this court should favour a mixed group or a
        // men's-only group, based on which gender is currently behind on
        // average games played — this is what stops every match from
        // becoming mixed whenever enough females are available.
        bool preferMixed = true;
        if (isFemale != null) {
          final femaleIdx = [for (int i = 0; i < n; i++) if (isFemale[i]) i];
          final maleIdx = [for (int i = 0; i < n; i++) if (!isFemale[i]) i];
          if (femaleIdx.isNotEmpty && maleIdx.isNotEmpty) {
            final avgFemalePlays = femaleIdx.fold<int>(
                    0, (a, i) => a + playCounts[i]) /
                femaleIdx.length;
            final avgMalePlays =
                maleIdx.fold<int>(0, (a, i) => a + playCounts[i]) /
                    maleIdx.length;
            preferMixed = avgFemalePlays <= avgMalePlays;
          }
        }

        final group = _pickGroup(candidates, partnerCount,
            isFemale: isFemale, preferMixed: preferMixed);
        if (group.length < 4) break;

        usedThisRound.addAll(group);

        // Sort the group by rating (desc), tiebreak by index, for snake-draft.
        final ranked = List<int>.from(group)
          ..sort((a, b) {
            final d = ratingOf(b).compareTo(ratingOf(a));
            return d != 0 ? d : a.compareTo(b);
          });

        // Three possible 2v2 splits for ranked [r0,r1,r2,r3]:
        //   A (snake): [r0,r3] vs [r1,r2]
        //   B:         [r0,r2] vs [r1,r3]
        //   C:         [r0,r1] vs [r2,r3]
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

        // When gender-aware, filter to splits where each team has the same
        // number of females (0 or 1) — guaranteeing mixed pairs face each other.
        final splitOptions = isFemale != null
            ? options.where((opt) {
                final aF = opt[0].where((i) => isFemale[i]).length;
                final bF = opt[1].where((i) => isFemale[i]).length;
                return aF == bF;
              }).toList()
            : options;

        final validSplits =
            splitOptions.isNotEmpty ? splitOptions : options;

        int minScore = 999999;
        var bestOpt = validSplits[0];
        for (final opt in validSplits) {
          final score = partnerCount[opt[0][0]][opt[0][1]] +
              partnerCount[opt[1][0]][opt[1][1]];
          if (score < minScore) {
            minScore = score;
            bestOpt = opt;
          }
        }

        // Record chosen partnerships.
        partnerCount[bestOpt[0][0]][bestOpt[0][1]]++;
        partnerCount[bestOpt[0][1]][bestOpt[0][0]]++;
        partnerCount[bestOpt[1][0]][bestOpt[1][1]]++;
        partnerCount[bestOpt[1][1]][bestOpt[1][0]]++;

        for (final p in group) {
          playCounts[p]++;
        }

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

  /// Picks 4 players from [avail] (sorted by play count, ascending) whose
  /// combined prior-partnership count is minimal.
  ///
  /// When [isFemale] is provided, enforces gender pairing — a group is
  /// either 4 males (men's doubles) or 2F + 2M (mixed doubles); a lone
  /// female is never picked. [preferMixed] picks which type is attempted
  /// first when both are possible; the other type is used as a fallback so
  /// a court is only left unfilled when neither type can be formed.
  static List<int> _pickGroup(
    List<int> avail,
    List<List<int>> partnerCount, {
    List<bool>? isFemale,
    bool preferMixed = true,
  }) {
    if (isFemale == null) {
      return _pickGroupFromPool(avail, partnerCount);
    }

    final females = avail.where((i) => isFemale[i]).toList();
    final males = avail.where((i) => !isFemale[i]).toList();

    final canMix = females.length >= 2 && males.length >= 2;
    final canMenOnly = males.length >= 4;

    if (preferMixed) {
      if (canMix) return _pickMixedGroup(females, males, partnerCount);
      if (canMenOnly) return _pickGroupFromPool(males, partnerCount);
    } else {
      if (canMenOnly) return _pickGroupFromPool(males, partnerCount);
      if (canMix) return _pickMixedGroup(females, males, partnerCount);
    }
    return []; // not enough players of the required genders
  }

  /// Picks the best 4 players from [pool] minimising total prior-partnership
  /// count. Anchors on pool[0] (least-played) and searches all C(rest,3).
  static List<int> _pickGroupFromPool(
      List<int> pool, List<List<int>> partnerCount) {
    if (pool.length <= 4) return pool.take(4).toList();

    final anchor = pool[0];
    final rest = pool.skip(1).toList();

    int bestScore = 999999;
    var best = [anchor, rest[0], rest[1], rest[2]];

    for (int i = 0; i < rest.length - 2; i++) {
      for (int j = i + 1; j < rest.length - 1; j++) {
        for (int k = j + 1; k < rest.length; k++) {
          final g = [anchor, rest[i], rest[j], rest[k]];
          final score = partnerCount[g[0]][g[1]] +
              partnerCount[g[0]][g[2]] +
              partnerCount[g[0]][g[3]] +
              partnerCount[g[1]][g[2]] +
              partnerCount[g[1]][g[3]] +
              partnerCount[g[2]][g[3]];
          if (score < bestScore) {
            bestScore = score;
            best = g;
            if (score == 0) break;
          }
        }
        if (bestScore == 0) break;
      }
      if (bestScore == 0) break;
    }

    return best;
  }

  /// Picks the best 2F + 2M group minimising total prior-partnership count.
  /// Anchors on [females][0] (least-played female).
  static List<int> _pickMixedGroup(
      List<int> females, List<int> males, List<List<int>> partnerCount) {
    final anchorF = females[0];

    int bestScore = 999999;
    var best = [anchorF, females[1], males[0], males[1]];

    for (int fi = 1; fi < females.length; fi++) {
      for (int mi = 0; mi < males.length - 1; mi++) {
        for (int mj = mi + 1; mj < males.length; mj++) {
          final g = [anchorF, females[fi], males[mi], males[mj]];
          final score = partnerCount[g[0]][g[1]] +
              partnerCount[g[0]][g[2]] +
              partnerCount[g[0]][g[3]] +
              partnerCount[g[1]][g[2]] +
              partnerCount[g[1]][g[3]] +
              partnerCount[g[2]][g[3]];
          if (score < bestScore) {
            bestScore = score;
            best = g;
            if (score == 0) break;
          }
        }
        if (bestScore == 0) break;
      }
      if (bestScore == 0) break;
    }

    return best;
  }
}
