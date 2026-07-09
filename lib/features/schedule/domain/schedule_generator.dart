import 'dart:math';

import 'schedule_model.dart';

class ScheduleGenerator {
  /// Each player plays exactly this many games per generated session.
  static const int gamesPerPlayer = 4;

  /// A player must rest for at least one round after playing this many
  /// consecutive rounds.
  static const int maxConsecutiveRounds = 2;

  /// Generates a session schedule for [playerIds] across [courts] simultaneous courts.
  ///
  /// Every player plays exactly [gamesPerPlayer] games, and never more than
  /// [maxConsecutiveRounds] rounds in a row without a rest round. Groups are
  /// chosen to spread each player across as much of the whole pool as
  /// possible (so over their games they meet as many different players as
  /// possible, rather than being stuck rotating with the same 3 people);
  /// within a chosen group of 4, the 2v2 split still follows current
  /// ranking — highest paired with lowest, second-highest with
  /// second-lowest — and never repeats an identical match if a fresher
  /// split is available.
  ///
  /// When [genders] is provided (playerId → 'male'|'female'), female players
  /// are always paired with a male partner (mixed doubles) — never alone.
  /// Mixed pairs only face other mixed pairs. If a round has an odd number
  /// of available females, the lowest-priority female sits out that court
  /// slot. Mixed groups are not forced whenever possible: men's-only doubles
  /// are also scheduled, with the mixed/men's-only split chosen each court so
  /// that females' average game count stays in step with males'.
  static List<ScheduledMatch> generate({
    required List<String> playerIds,
    required int courts,
    Map<String, int>? ratings,
    Map<String, String>? genders,
    Random? random,
  }) {
    final n = playerIds.length;
    if (n < 4) return [];

    // Breaks ties when multiple groupings are equally good, so regenerating
    // the same roster doesn't always produce byte-identical schedules.
    final rng = random ?? Random();

    // Index-based gender flag: isFemale[i] == true if playerIds[i] is female.
    final isFemale = genders != null
        ? [for (int i = 0; i < n; i++) genders[playerIds[i]] == 'female']
        : null;

    final activeCourts = courts.clamp(1, n ~/ 4);

    int ratingOf(int i) => ratings?[playerIds[i]] ?? 0;

    final playCounts = List.filled(n, 0);
    final consecutiveRounds = List.filled(n, 0);
    // How many times each pair of players has shared a match (as partners
    // or opponents) — drives group selection toward meeting everyone.
    final metCount = List.generate(n, (_) => List.filled(n, 0));
    // How many times each pair has specifically been TEAMMATES — being
    // partnered with the same person again reads as far more repetitive
    // than merely facing them again, so this is checked separately and
    // takes priority when choosing a group's 2v2 split.
    final partnerCount = List.generate(n, (_) => List.filled(n, 0));
    final playedSignatures = <String>{};

    final matches = <ScheduledMatch>[];
    int matchNumber = 0;

    // Safety cap on rounds — mandatory rest rounds mean more rounds are
    // needed than raw game count would suggest, so this is generous.
    final maxRounds = n * gamesPerPlayer * 2;
    int consecutiveEmptyRounds = 0;

    for (int round = 1; round <= maxRounds; round++) {
      if (playCounts.every((c) => c >= gamesPerPlayer)) break;

      final restingOut = <int>{
        for (int i = 0; i < n; i++)
          if (consecutiveRounds[i] >= maxConsecutiveRounds) i,
      };

      final usedThisRound = <int>{};
      bool anyMatchThisRound = false;

      for (int c = 0; c < activeCourts; c++) {
        // Still-needed, not-resting players not yet assigned this round,
        // sorted by fewest games first so everyone reaches gamesPerPlayer
        // together.
        final avail = [
          for (int i = 0; i < n; i++)
            if (!usedThisRound.contains(i) &&
                !restingOut.contains(i) &&
                playCounts[i] < gamesPerPlayer)
              i,
        ]..sort((a, b) {
            final d = playCounts[a].compareTo(playCounts[b]);
            return d != 0 ? d : a.compareTo(b);
          });

        // Gender-aware: ensure an even number of females in candidates so
        // every female can be paired with a male partner.
        List<int> candidates = avail;
        if (isFemale != null) {
          final femalesInAvail = avail.where((i) => isFemale[i]).toList();
          if (femalesInAvail.length == 1) {
            // With an odd total female count, one female can end up
            // permanently stranded once every other female has already
            // reached gamesPerPlayer — there's no one left to legally pair
            // her with. Rescue her by pulling in whichever other female
            // (anywhere, even past her own target, even if resting) has
            // played the fewest total games, rather than benching the
            // stuck player forever.
            final stuck = femalesInAvail.first;
            final otherFemales = [
              for (int i = 0; i < n; i++)
                if (isFemale[i] && i != stuck && !usedThisRound.contains(i))
                  i,
            ]..sort((a, b) => playCounts[a].compareTo(playCounts[b]));
            if (otherFemales.isNotEmpty) {
              final helper = otherFemales.first;
              candidates = {...avail, helper}.toList();
            } else {
              candidates = avail.where((i) => i != stuck).toList();
            }
          } else if (femalesInAvail.length % 2 == 1) {
            final sittingOut = femalesInAvail.last;
            candidates = avail.where((i) => i != sittingOut).toList();
          }
        }

        if (candidates.length < 4) continue;

        // Decide whether this court should favour a mixed group or a
        // men's-only group, based on which gender is currently behind on
        // average games played — this is what stops every match from
        // becoming mixed whenever enough females are available.
        bool preferMixed = true;
        if (isFemale != null) {
          final femaleIdx = [for (int i = 0; i < n; i++) if (isFemale[i]) i];
          final maleIdx = [for (int i = 0; i < n; i++) if (!isFemale[i]) i];
          if (femaleIdx.isNotEmpty && maleIdx.isNotEmpty) {
            final avgFemalePlays =
                femaleIdx.fold<int>(0, (a, i) => a + playCounts[i]) /
                    femaleIdx.length;
            final avgMalePlays =
                maleIdx.fold<int>(0, (a, i) => a + playCounts[i]) /
                    maleIdx.length;
            preferMixed = avgFemalePlays <= avgMalePlays;
          }
        }

        final group = _pickGroup(
            candidates, ratingOf, (i) => playCounts[i], metCount, rng,
            isFemale: isFemale, preferMixed: preferMixed);
        if (group.length < 4) continue;

        usedThisRound.addAll(group);
        anyMatchThisRound = true;

        // Record that every pair in this group has now met, regardless of
        // team assignment — this is what future rounds use to spread each
        // player across the whole pool instead of a fixed sub-group.
        for (int a = 0; a < group.length; a++) {
          for (int b = a + 1; b < group.length; b++) {
            metCount[group[a]][group[b]]++;
            metCount[group[b]][group[a]]++;
          }
        }

        // Sort the group by rating (desc), tiebreak by index.
        final ranked = List<int>.from(group)
          ..sort((a, b) {
            final d = ratingOf(b).compareTo(ratingOf(a));
            return d != 0 ? d : a.compareTo(b);
          });

        // Three possible 2v2 splits for ranked [r0,r1,r2,r3], in order of
        // preference — rank-based first (highest + lowest vs the middle
        // two), since teams follow current ranking rather than
        // partner-repeat avoidance:
        //   A (rank-based): [r0,r3] vs [r1,r2]
        //   B:               [r0,r2] vs [r1,r3]
        //   C:               [r0,r1] vs [r2,r3]
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
        // number of females (0 or 1) — guaranteeing mixed pairs face each
        // other. Options stay in rank-preference order.
        final splitOptions = isFemale != null
            ? options.where((opt) {
                final aF = opt[0].where((i) => isFemale[i]).length;
                final bF = opt[1].where((i) => isFemale[i]).length;
                return aF == bF;
              }).toList()
            : options;

        final validSplits = splitOptions.isNotEmpty ? splitOptions : options;

        // Choose the split that repeats the fewest prior PARTNERSHIPS first
        // — being teamed up with someone again reads as far more
        // repetitive than merely facing them again — then the most
        // rank-faithful option among those, then whichever isn't an exact
        // repeat of a match already played. Each factor only breaks ties
        // left by the one before it, so rank/duplicate-avoidance still
        // apply whenever no split can avoid a partner repeat.
        var bestOpt = validSplits.first;
        int bestScore = 1 << 30;
        for (int idx = 0; idx < validSplits.length; idx++) {
          final opt = validSplits[idx];
          final partnerRepeats = partnerCount[opt[0][0]][opt[0][1]] +
              partnerCount[opt[1][0]][opt[1][1]];
          final isDup =
              playedSignatures.contains(_matchSignature(opt[0], opt[1]));
          final score = partnerRepeats * 1000 + idx * 10 + (isDup ? 1 : 0);
          if (score < bestScore) {
            bestScore = score;
            bestOpt = opt;
          }
        }
        playedSignatures.add(_matchSignature(bestOpt[0], bestOpt[1]));
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

      for (int i = 0; i < n; i++) {
        if (usedThisRound.contains(i)) {
          consecutiveRounds[i]++;
        } else {
          consecutiveRounds[i] = 0;
        }
      }

      if (anyMatchThisRound) {
        consecutiveEmptyRounds = 0;
      } else {
        consecutiveEmptyRounds++;
        // A single empty round is expected — it's a mandatory rest cycle
        // when a whole active group is resting simultaneously. Two empty
        // rounds in a row while games are still owed means we're actually
        // stuck (e.g. gender constraints leave someone unmatchable).
        if (consecutiveEmptyRounds >= 2) break;
      }
    }

    return matches;
  }

  /// A canonical, order-independent signature for a 2v2 match — used to
  /// detect when a split would recreate an exact match already played.
  static String _matchSignature(List<int> teamA, List<int> teamB) {
    final aKey = (List<int>.from(teamA)..sort()).join(',');
    final bKey = (List<int>.from(teamB)..sort()).join(',');
    final keys = [aKey, bKey]..sort();
    return keys.join('|');
  }

  /// Picks 4 players for a match. When [isFemale] is provided, enforces
  /// gender pairing — a group is either 4 males (men's doubles) or 2F + 2M
  /// (mixed doubles); a lone female is never picked. [preferMixed] picks
  /// which type is attempted first when both are possible; the other type
  /// is used as a fallback so a court is only left unfilled when neither
  /// type can be formed.
  static List<int> _pickGroup(
    List<int> avail,
    int Function(int) ratingOf,
    int Function(int) playCountOf,
    List<List<int>> metCount,
    Random rng, {
    List<bool>? isFemale,
    bool preferMixed = true,
  }) {
    if (isFemale == null) {
      return _pickGroupFromPool(avail, ratingOf, playCountOf, metCount, rng);
    }

    final females = avail.where((i) => isFemale[i]).toList();
    final males = avail.where((i) => !isFemale[i]).toList();

    final canMix = females.length >= 2 && males.length >= 2;
    final canMenOnly = males.length >= 4;

    if (preferMixed) {
      if (canMix) {
        return _pickMixedGroup(females, males, ratingOf, playCountOf, metCount, rng);
      }
      if (canMenOnly) {
        return _pickGroupFromPool(males, ratingOf, playCountOf, metCount, rng);
      }
    } else {
      if (canMenOnly) {
        return _pickGroupFromPool(males, ratingOf, playCountOf, metCount, rng);
      }
      if (canMix) {
        return _pickMixedGroup(females, males, ratingOf, playCountOf, metCount, rng);
      }
    }
    return []; // not enough players of the required genders
  }

  /// Picks exactly [need] players from [pool] (sorted by fewest games
  /// played first). Whole play-count tiers are consumed least-played-first
  /// — fairness always wins. Within a tier too big to fully fit in what's
  /// left of [need], the subset that has met [alreadyPicked] and each other
  /// the fewest times is chosen — spreading each player across the whole
  /// pool instead of a fixed sub-group — tied candidates are broken first by
  /// widest rating spread (so ranking still guides who ends up paired
  /// together), then randomly, so regenerating the same roster doesn't
  /// always land on an identical schedule.
  static List<int> _pickByNeed(
    List<int> pool,
    int need,
    int Function(int) ratingOf,
    int Function(int) playCountOf,
    List<List<int>> metCount,
    Random rng, [
    List<int> alreadyPicked = const [],
  ]) {
    if (pool.length <= need) return List<int>.from(pool);

    final picked = <int>[];
    int i = 0;
    while (picked.length < need && i < pool.length) {
      final count = playCountOf(pool[i]);
      int j = i;
      while (j < pool.length && playCountOf(pool[j]) == count) {
        j++;
      }
      final tier = pool.sublist(i, j);

      final remaining = need - picked.length;
      if (tier.length <= remaining) {
        picked.addAll(tier);
      } else {
        final chosen = _leastMetSubset(tier, remaining,
            [...alreadyPicked, ...picked], ratingOf, metCount, rng);
        picked.addAll(chosen);
      }
      i = j;
    }
    return picked;
  }

  /// Picks the [k]-sized subset of [tier] that has met each other and
  /// [context] the fewest times so far, breaking ties by preferring the
  /// widest rating spread (keeps highest-vs-lowest pairing intent alive
  /// when there's no variety reason to prefer otherwise), and breaking any
  /// remaining tie randomly so the same roster doesn't always regenerate an
  /// identical schedule.
  static List<int> _leastMetSubset(List<int> tier, int k, List<int> context,
      int Function(int) ratingOf, List<List<int>> metCount, Random rng) {
    final combos = _combinations(tier, k);
    int bestScore = 1 << 30;
    int bestSpread = -1;
    var bestCombos = <List<int>>[];

    for (final combo in combos) {
      int score = 0;
      for (int a = 0; a < combo.length; a++) {
        for (int b = a + 1; b < combo.length; b++) {
          score += metCount[combo[a]][combo[b]];
        }
        for (final p in context) {
          score += metCount[combo[a]][p];
        }
      }
      final ratingsInCombo = combo.map(ratingOf).toList();
      final spread = ratingsInCombo.reduce((x, y) => x > y ? x : y) -
          ratingsInCombo.reduce((x, y) => x < y ? x : y);

      if (score < bestScore || (score == bestScore && spread > bestSpread)) {
        bestScore = score;
        bestSpread = spread;
        bestCombos = [combo];
      } else if (score == bestScore && spread == bestSpread) {
        bestCombos.add(combo);
      }
    }
    return bestCombos[rng.nextInt(bestCombos.length)];
  }

  static List<List<int>> _combinations(List<int> items, int k) {
    if (k <= 0) return [<int>[]];
    if (items.length < k) return [];

    final result = <List<int>>[];
    final current = <int>[];
    void combine(int start) {
      if (current.length == k) {
        result.add(List<int>.from(current));
        return;
      }
      for (int idx = start; idx < items.length; idx++) {
        current.add(items[idx]);
        combine(idx + 1);
        current.removeLast();
      }
    }

    combine(0);
    return result;
  }

  /// Picks 4 players from [pool] — least-met-first, ranking only guiding
  /// which of equally-fresh candidates end up together.
  static List<int> _pickGroupFromPool(List<int> pool, int Function(int) ratingOf,
      int Function(int) playCountOf, List<List<int>> metCount, Random rng) {
    return _pickByNeed(pool, 4, ratingOf, playCountOf, metCount, rng);
  }

  /// Picks a 2F + 2M group by applying the same needs-first, least-met
  /// selection independently within each gender.
  static List<int> _pickMixedGroup(
      List<int> females,
      List<int> males,
      int Function(int) ratingOf,
      int Function(int) playCountOf,
      List<List<int>> metCount,
      Random rng) {
    final pickedF =
        _pickByNeed(females, 2, ratingOf, playCountOf, metCount, rng);
    final pickedM = _pickByNeed(
        males, 2, ratingOf, playCountOf, metCount, rng, pickedF);
    return [...pickedF, ...pickedM];
  }
}
