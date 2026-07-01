import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_provider.dart';
import '../../../league/data/league_cloud_repository.dart';
import '../../../player/data/player_model.dart';

final leaderboardProvider = FutureProvider.family<List<PlayerModel>, String>(
  (ref, leagueId) async {
    final db = ref.read(firestoreProvider);
    final repo = LeagueCloudRepository(db);
    final players = await repo.getLeaguePlayers(leagueId);
    players.sort((a, b) => b.rating.compareTo(a.rating));
    return players;
  },
);
