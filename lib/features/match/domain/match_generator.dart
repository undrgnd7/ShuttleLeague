class MatchGenerator {
  /// Creates balanced 2v2 matches using ELO snake-draft pairing.
  /// Players are sorted by rating; best+worst form one team, middle two form the other.
  /// This minimises the rating gap between teams.
  static List<List<List<String>>> generateDoubles(
    List<String> playerIds, {
    Map<String, int>? ratings,
  }) {
    final sorted = List<String>.from(playerIds);

    if (ratings != null && ratings.isNotEmpty) {
      sorted.sort((a, b) =>
          (ratings[b] ?? 1000).compareTo(ratings[a] ?? 1000));
    } else {
      sorted.shuffle();
    }

    final matches = <List<List<String>>>[];

    for (int i = 0; i + 3 < sorted.length; i += 4) {
      // Snake-draft: ranks 1 & 4 vs ranks 2 & 3 — most balanced pairing
      final teamA = [sorted[i], sorted[i + 3]];
      final teamB = [sorted[i + 1], sorted[i + 2]];
      matches.add([teamA, teamB]);
    }

    return matches;
  }
}
