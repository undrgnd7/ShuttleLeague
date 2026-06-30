class MatchGenerator {
  /// Creates balanced 2v2 matches
  static List<List<List<String>>> generateDoubles(List<String> players) {
    final shuffled = List<String>.from(players)..shuffle();

    final matches = <List<List<String>>>[];

    for (int i = 0; i < shuffled.length; i += 4) {
      if (i + 3 >= shuffled.length) break;

      final teamA = [shuffled[i], shuffled[i + 1]];
      final teamB = [shuffled[i + 2], shuffled[i + 3]];

      matches.add([teamA, teamB]);
    }

    return matches;
  }
}
