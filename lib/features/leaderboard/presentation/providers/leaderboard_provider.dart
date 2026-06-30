import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../player/data/player_model.dart';

final leaderboardProvider = FutureProvider.family<List<PlayerModel>, String>(
  (ref, leagueId) async {
    final db = ref.read(databaseProvider);

    final rows = await db.select(db.players).get();

    final players = rows.map((p) {
      return PlayerModel(
        id: p.id,
        name: p.name,
        skillLevel: p.skillLevel,
        rating: p.rating,
        wins: p.wins,
        losses: p.losses,
        createdAt: p.createdAt,
      );
    }).toList();

    players.sort((a, b) => b.rating.compareTo(a.rating));

    return players;
  },
);
