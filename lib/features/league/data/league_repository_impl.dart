import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
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
      mode: InsertMode.insertOrReplace,
    );
  }

  @override
  Future<List<LeagueModel>> getLeagues() async {
    final rows = await db.select(db.leagues).get();

    return rows
        .map(
          (l) => LeagueModel(
            id: l.id,
            name: l.name,
            maxPlayers: l.maxPlayers,
            createdAt: l.createdAt,
          ),
        )
        .toList();
  }
}
