import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../leaderboard/domain/elo_engine.dart';
import '../domain/player_repository.dart';
import 'player_model.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final AppDatabase db;

  PlayerRepositoryImpl(this.db);

  @override
  Future<void> addPlayer(PlayerModel player) async {
    if (await isNameTaken(player.name)) {
      throw Exception('A player named "${player.name}" already exists');
    }
    await db.into(db.players).insert(
      PlayersCompanion.insert(
        id: player.id,
        name: player.name,
        skillLevel: Value(player.skillLevel),
        createdAt: player.createdAt,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  @override
  Future<List<PlayerModel>> getPlayers() async {
    final rows = await db.select(db.players).get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<PlayerModel?> getPlayer(String id) async {
    final rows = await (db.select(db.players)
          ..where((p) => p.id.equals(id)))
        .get();
    return rows.isEmpty ? null : _toModel(rows.first);
  }

  @override
  Future<void> updatePlayer(PlayerModel player) async {
    await (db.update(db.players)..where((p) => p.id.equals(player.id)))
        .write(PlayersCompanion(
      name: Value(player.name),
      skillLevel: Value(player.skillLevel),
    ));
  }

  @override
  Future<void> deletePlayer(String id) async {
    await (db.delete(db.players)..where((p) => p.id.equals(id))).go();
    await (db.delete(db.leaguePlayers)..where((lp) => lp.playerId.equals(id)))
        .go();
  }

  @override
  Future<bool> isNameTaken(String name) async {
    final normalized = name.trim().toLowerCase();
    final rows = await db.select(db.players).get();
    return rows.any((p) => p.name.trim().toLowerCase() == normalized);
  }

  @override
  Future<void> recordMatchResult({
    required String leagueId,
    required List<String> winnerIds,
    required List<String> loserIds,
  }) async {
    final allIds = [...winnerIds, ...loserIds];
    final allRows = await (db.select(db.players)
          ..where((p) => p.id.isIn(allIds)))
        .get();

    final Map<String, dynamic> ratingMap = {
      for (final r in allRows) r.id: r.rating,
    };

    final avgWinnerRating = winnerIds.isEmpty
        ? 1000
        : (winnerIds.fold<int>(0, (s, id) => s + (ratingMap[id] as int? ?? 1000)) /
                winnerIds.length)
            .round();
    final avgLoserRating = loserIds.isEmpty
        ? 1000
        : (loserIds.fold<int>(0, (s, id) => s + (ratingMap[id] as int? ?? 1000)) /
                loserIds.length)
            .round();

    for (final id in winnerIds) {
      final current = ratingMap[id] as int? ?? 1000;
      final newRating = EloEngine.calculateNewRating(
        rating: current,
        opponentRating: avgLoserRating,
        won: true,
      );
      final row = allRows.firstWhere((r) => r.id == id);
      await (db.update(db.players)..where((p) => p.id.equals(id))).write(
        PlayersCompanion(
          rating: Value(newRating),
          wins: Value(row.wins + 1),
        ),
      );
    }

    for (final id in loserIds) {
      final current = ratingMap[id] as int? ?? 1000;
      final newRating = EloEngine.calculateNewRating(
        rating: current,
        opponentRating: avgWinnerRating,
        won: false,
      );
      final row = allRows.firstWhere((r) => r.id == id);
      await (db.update(db.players)..where((p) => p.id.equals(id))).write(
        PlayersCompanion(
          rating: Value(newRating),
          losses: Value(row.losses + 1),
        ),
      );
    }
  }

  @override
  Future<void> editMatchResult({
    required String leagueId,
    required List<String> oldWinnerIds,
    required List<String> oldLoserIds,
  }) async {
    // SQLite path not used — Firestore handles this
  }

  PlayerModel _toModel(dynamic p) => PlayerModel(
        id: p.id,
        name: p.name,
        skillLevel: p.skillLevel,
        rating: p.rating,
        wins: p.wins,
        losses: p.losses,
        createdAt: p.createdAt,
      );
}
