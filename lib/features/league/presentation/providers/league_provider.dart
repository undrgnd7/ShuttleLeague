import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../player/data/player_model.dart';
import '../../data/league_repository_impl.dart';
import '../../domain/league_repository.dart';

final leagueDetailPlayersProvider =
    FutureProvider.family<List<PlayerModel>, String>((ref, leagueId) {
  final db = ref.read(databaseProvider);
  final repo = LeagueRepositoryImpl(db);

  return repo.getLeaguePlayers(leagueId);
});
