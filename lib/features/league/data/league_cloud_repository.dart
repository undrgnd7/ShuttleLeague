import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/league_repository.dart';
import 'league_model.dart';
import '../../player/data/player_model.dart';

class LeagueCloudRepository implements LeagueRepository {
  final FirebaseFirestore _db;

  LeagueCloudRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _leagues =>
      _db.collection('leagues');

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection('players');

  @override
  Future<void> createLeague(LeagueModel league) async {
    if (await isNameTaken(league.name)) {
      throw Exception('A league named "${league.name}" already exists.');
    }
    await _leagues.doc(league.id).set({
      'name': league.name,
      'maxPlayers': league.maxPlayers,
      'createdAt': Timestamp.fromDate(league.createdAt),
    });
  }

  @override
  Future<List<LeagueModel>> getLeagues() async {
    final snap = await _leagues.orderBy('createdAt', descending: true).get();
    return snap.docs.map(_docToLeagueModel).toList();
  }

  Stream<List<LeagueModel>> watchLeagues() {
    return _leagues
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_docToLeagueModel).toList());
  }

  @override
  Future<void> updateLeague(LeagueModel league) async {
    await _leagues.doc(league.id).update({
      'name': league.name,
      'maxPlayers': league.maxPlayers,
    });
  }

  @override
  Future<void> deleteLeague(String id) async {
    final memberships = await _leagues.doc(id).collection('players').get();
    final batch = _db.batch();
    for (final doc in memberships.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_leagues.doc(id));
    await batch.commit();
  }

  @override
  Future<bool> isNameTaken(String name) async {
    final snap = await _leagues
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<void> addPlayerToLeague({
    required String leagueId,
    required PlayerModel player,
  }) async {
    // Use setOptions merge:true so re-adding a player doesn't reset their points
    await _leagues.doc(leagueId).collection('players').doc(player.id).set({
      'playerId': player.id,
      'joinedAt': Timestamp.now(),
      'rating': 0,
      'wins': 0,
      'losses': 0,
    }, SetOptions(merge: false)); // fresh entry for new members
  }

  @override
  Future<List<PlayerModel>> getLeaguePlayers(String leagueId) async {
    final memberSnap =
        await _leagues.doc(leagueId).collection('players').get();

    if (memberSnap.docs.isEmpty) return [];

    // Per-league stats live in the subcollection doc itself
    final memberMap = <String, Map<String, dynamic>>{
      for (final d in memberSnap.docs) d.id: d.data(),
    };

    // Fetch global player docs for name / skillLevel / createdAt
    final playerDocs = await Future.wait(
      memberMap.keys.map((id) => _players.doc(id).get()),
    );

    return playerDocs
        .where((doc) => doc.exists)
        .map((doc) {
          final g = doc.data()!;
          final l = memberMap[doc.id] ?? {};
          return PlayerModel(
            id: doc.id,
            name: g['name'] as String,
            skillLevel: (g['skillLevel'] as num?)?.toInt() ?? 1,
            // Per-league points, NOT global
            rating: (l['rating'] as num?)?.toInt() ?? 0,
            wins: (l['wins'] as num?)?.toInt() ?? 0,
            losses: (l['losses'] as num?)?.toInt() ?? 0,
            createdAt: (g['createdAt'] as Timestamp).toDate(),
            gender: g['gender'] == 'female'
                ? PlayerGender.female
                : PlayerGender.male,
          );
        })
        .toList();
  }

  LeagueModel _docToLeagueModel(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return LeagueModel(
      id: doc.id,
      name: d['name'] as String,
      maxPlayers: (d['maxPlayers'] as num?)?.toInt() ?? 16,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

}
