import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../domain/player_repository.dart';
import 'player_model.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final AppDatabase db;

  PlayerRepositoryImpl(this.db);

  @override
  Future<void> addPlayer(PlayerModel player) async {
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

    return rows
        .map(
          (p) => PlayerModel(
            id: p.id,
            name: p.name,
            skillLevel: p.skillLevel,
            createdAt: p.createdAt,
          ),
        )
        .toList();
  }
}
