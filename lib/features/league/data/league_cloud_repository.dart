import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/league_repository.dart';
import 'league_model.dart';

class LeagueCloudRepository implements LeagueRepository {
  final FirebaseFirestore firestore;

  LeagueCloudRepository(this.firestore);

  CollectionReference get _leagues => firestore.collection('leagues');

  @override
  Future<void> createLeague(LeagueModel league) async {
    await _leagues.doc(league.id).set({
      'name': league.name,
      'maxPlayers': league.maxPlayers,
      'createdAt': league.createdAt.toIso8601String(),
    });
  }

  @override
  Future<List<LeagueModel>> getLeagues() async {
    final snapshot = await _leagues.get();

    return snapshot.docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;

      return LeagueModel(
        id: doc.id,
        name: d['name'],
        maxPlayers: d['maxPlayers'],
        createdAt: DateTime.parse(d['createdAt']),
      );
    }).toList();
  }

  @override
  Future<void> addPlayerToLeague({
    required String leagueId,
    required player,
  }) async {
    await _leagues
        .doc(leagueId)
        .collection('players')
        .add({
      'playerId': player.id,
      'name': player.name,
      'skillLevel': player.skillLevel,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List> getLeaguePlayers(String leagueId) async {
    final snapshot =
        await _leagues.doc(leagueId).collection('players').get();

    return snapshot.docs.map((d) => d.data()).toList();
  }
}
