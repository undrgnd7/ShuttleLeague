import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../player/data/player_model.dart';
import '../domain/league_repository.dart';
import 'league_model.dart';

class LeagueRepositoryImpl implements LeagueRepository {
  final AppDatabase db;

  LeagueRepositoryImpl(this.db);

  @override
  Future<void> createLeague(LeagueModel league) async {
    await db.into(db.leagues).insert(
      LeaguesCompanion.insert(
        id: league.id,
        name: league.name,
        maxPlayers: league.maxPlayers,
        createdAt: league.createdAt,
      ),
    );
  }

  @override
  Future<List<LeagueModel>> getLeagues() async {
    final rows = await db.select(db.leagues).get();

    return rows
        .map((l) => LeagueModel(
              id: l.id,
              name: l.name,
              maxPlayers: l.maxPlayers,
              createdAt: l.createdAt,
            ))
        .toList();
  }

  // NEW: add player to league
  @override
  Future<void> addPlayerToLeague({
    required String leagueId,
    required PlayerModel player,
  }) async {
    final joinId = const Uuid().v4();

    await db.into(db.leaguePlayers).insert(
      LeaguePlayersCompanion.insert(
        id: joinId,
        leagueId: leagueId,
        playerId: player.id,
        joinedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // NEW: get players in league
  @override
  Future<List<PlayerModel>> getLeaguePlayers(String leagueId) async {
    final query = db.select(db.leaguePlayers).join([
      innerJoin(
        db.players,
        db.players.id.equalsExp(db.leaguePlayers.playerId),
      ),
    ])
      ..where(db.leaguePlayers.leagueId.equals(leagueId));

    final rows = await query.get();

    return rows.map((row) {
      final p = row.readTable(db.players);

      return PlayerModel(
        id: p.id,
        name: p.name,
        skillLevel: p.skillLevel,
        createdAt: p.createdAt,
      );
    }).toList();
  }
}
