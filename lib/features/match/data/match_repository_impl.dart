import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../player/data/player_model.dart';
import '../../player/domain/player_repository.dart';
import '../domain/match_model.dart';
import '../domain/match_generator.dart';
import '../domain/match_repository.dart';

class MatchRepositoryImpl implements MatchRepository {
  final AppDatabase db;
  final PlayerRepository playerRepository;

  MatchRepositoryImpl(this.db, this.playerRepository);

  @override
  Future<List<MatchModel>> getMatches(String sessionId) async {
    final rows = await (db.select(db.matches)
          ..where((m) => m.sessionId.equals(sessionId)))
        .get();

    return rows
        .map(
          (m) => MatchModel(
            id: m.id,
            leagueId: m.leagueId,
            sessionId: m.sessionId,
            teamA: [m.teamAPlayer1, m.teamAPlayer2],
            teamB: [m.teamBPlayer1, m.teamBPlayer2],
            createdAt: m.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> generateMatches({
    required String leagueId,
    required String sessionId,
    required List<String> playerIds,
  }) async {
    final players = await playerRepository.getPlayers();
    final genders = {
      for (final p in players)
        if (playerIds.contains(p.id))
          p.id: p.gender == PlayerGender.female ? 'female' : 'male',
    };

    final generated =
        MatchGenerator.generateDoubles(playerIds, genders: genders);

    for (final match in generated) {
      final teamA = match[0];
      final teamB = match[1];

      await db.into(db.matches).insert(
        MatchesCompanion.insert(
          id: const Uuid().v4(),
          leagueId: leagueId,
          sessionId: sessionId,
          teamAPlayer1: teamA[0],
          teamAPlayer2: teamA[1],
          teamBPlayer1: teamB[0],
          teamBPlayer2: teamB[1],
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}
