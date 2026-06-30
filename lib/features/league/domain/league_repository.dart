import '../data/league_model.dart';

abstract class LeagueRepository {
  Future<List<LeagueModel>> getLeagues();
  Future<void> createLeague(LeagueModel league);
}
