class MatchGenerator {
  /// Creates balanced 2v2 matches using ELO snake-draft pairing.
  /// Players are sorted by rating; best+worst form one team, middle two form the other.
  /// This minimises the rating gap between teams.
  ///
  /// When [genders] is provided (playerId → 'male'|'female'), enforces the same
  /// gender-balance rule as [ScheduleGenerator]: every match has either 0 or
  /// exactly 2 female players, split 1-and-1 across the two teams (mixed
  /// doubles). If an odd number of females is available, the lowest-rated
  /// female sits out this generation.
  static List<List<List<String>>> generateDoubles(
    List<String> playerIds, {
    Map<String, int>? ratings,
    Map<String, String>? genders,
  }) {
    List<String> sortedByRating(List<String> ids) {
      final list = List<String>.from(ids);
      if (ratings != null && ratings.isNotEmpty) {
        list.sort(
            (a, b) => (ratings[b] ?? 1000).compareTo(ratings[a] ?? 1000));
      } else {
        list.shuffle();
      }
      return list;
    }

    List<List<List<String>>> snakeDraft(List<String> sorted) {
      final matches = <List<List<String>>>[];
      for (int i = 0; i + 3 < sorted.length; i += 4) {
        // Snake-draft: ranks 1 & 4 vs ranks 2 & 3 — most balanced pairing
        final teamA = [sorted[i], sorted[i + 3]];
        final teamB = [sorted[i + 1], sorted[i + 2]];
        matches.add([teamA, teamB]);
      }
      return matches;
    }

    if (genders == null || genders.isEmpty) {
      return snakeDraft(sortedByRating(playerIds));
    }

    final females =
        sortedByRating(playerIds.where((id) => genders[id] == 'female').toList());
    final males =
        sortedByRating(playerIds.where((id) => genders[id] != 'female').toList());

    // Never leave exactly 1 female unpaired — sit out the lowest-rated one.
    final usableFemales =
        females.length.isOdd ? females.sublist(0, females.length - 1) : females;

    final matches = <List<List<String>>>[];

    // Mixed matches: 2 females + 2 males, 1 female + 1 male per team.
    int mi = 0;
    for (int fi = 0;
        fi + 1 < usableFemales.length && mi + 1 < males.length;
        fi += 2, mi += 2) {
      matches.add([
        [usableFemales[fi], males[mi]],
        [usableFemales[fi + 1], males[mi + 1]],
      ]);
    }

    // Remaining males (already rating-sorted) form standard all-male matches.
    matches.addAll(snakeDraft(males.sublist(mi)));

    return matches;
  }
}
