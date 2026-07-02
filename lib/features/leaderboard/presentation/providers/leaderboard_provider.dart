import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_provider.dart';
import '../../../league/data/league_cloud_repository.dart';
import '../../../player/data/player_cloud_repository.dart';
import '../../../player/data/player_model.dart';

/// Per-league leaderboard — points within a single league.
final leaderboardProvider = FutureProvider.family<List<PlayerModel>, String>(
  (ref, leagueId) async {
    final db = ref.read(firestoreProvider);
    final repo = LeagueCloudRepository(db);
    final players = await repo.getLeaguePlayers(leagueId);
    players.sort((a, b) {
      final rDiff = b.rating.compareTo(a.rating);
      if (rDiff != 0) return rDiff;
      return b.wins.compareTo(a.wins);
    });
    return players;
  },
);

/// Overall leaderboard — lifetime points across all leagues, real-time.
final overallLeaderboardProvider = StreamProvider<List<PlayerModel>>(
  (ref) {
    final db = ref.read(firestoreProvider);
    return PlayerCloudRepository(db).watchPlayers().map((players) {
      final sorted = List<PlayerModel>.from(players)
        ..sort((a, b) {
          final rDiff = b.rating.compareTo(a.rating);
          if (rDiff != 0) return rDiff;
          return b.wins.compareTo(a.wins);
        });
      return sorted;
    });
  },
);
