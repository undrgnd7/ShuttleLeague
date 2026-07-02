import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/player_repository.dart';
import 'player_model.dart';
import '../../leaderboard/domain/elo_engine.dart';

class PlayerCloudRepository implements PlayerRepository {
  final FirebaseFirestore _db;

  PlayerCloudRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection('players');

  @override
  Future<void> addPlayer(PlayerModel player) async {
    await _players.doc(player.id).set({
      'name': player.name,
      'skillLevel': player.skillLevel,
      'gender': player.gender.name,
      'rating': player.rating,
      'wins': player.wins,
      'losses': player.losses,
      'createdAt': Timestamp.fromDate(player.createdAt),
    });
  }

  @override
  Future<List<PlayerModel>> getPlayers() async {
    final snap = await _players.orderBy('name').get();
    return snap.docs.map(_docToModel).toList();
  }

  Stream<List<PlayerModel>> watchPlayers() {
    return _players.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(_docToModel).toList(),
        );
  }

  @override
  Future<PlayerModel?> getPlayer(String id) async {
    final doc = await _players.doc(id).get();
    if (!doc.exists) return null;
    return _docToModel(doc);
  }

  @override
  Future<void> updatePlayer(PlayerModel player) async {
    await _players.doc(player.id).update({
      'name': player.name,
      'skillLevel': player.skillLevel,
      'gender': player.gender.name,
    });
  }

  @override
  Future<void> deletePlayer(String id) async {
    // Remove all league memberships for this player via collection group query
    final memberships = await _db
        .collectionGroup('players')
        .where('playerId', isEqualTo: id)
        .get();

    final batch = _db.batch();
    for (final doc in memberships.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_players.doc(id));
    await batch.commit();
  }

  @override
  Future<bool> isNameTaken(String name) async {
    final snap = await _players
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<void> recordMatchResult({
    required String leagueId,
    required List<String> winnerIds,
    required List<String> loserIds,
  }) async {
    final allIds = [...winnerIds, ...loserIds];
    final globalRefs = allIds.map((id) => _players.doc(id)).toList();
    final leagueRefs = allIds
        .map((id) => _db
            .collection('leagues')
            .doc(leagueId)
            .collection('players')
            .doc(id))
        .toList();

    await _db.runTransaction((tx) async {
      // Read phase
      final globalSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in globalRefs) {
        globalSnaps.add(await tx.get(ref));
      }
      final leagueSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in leagueRefs) {
        leagueSnaps.add(await tx.get(ref));
      }

      // Write phase
      for (int i = 0; i < allIds.length; i++) {
        final isWinner = winnerIds.contains(allIds[i]);
        final pts = isWinner ? EloEngine.pointsForWin : EloEngine.pointsForLoss;

        // Update global lifetime stats
        if (globalSnaps[i].exists) {
          final d = globalSnaps[i].data()!;
          tx.update(globalRefs[i], {
            'rating': (d['rating'] as int? ?? 0) + pts,
            'wins': (d['wins'] as int? ?? 0) + (isWinner ? 1 : 0),
            'losses': (d['losses'] as int? ?? 0) + (isWinner ? 0 : 1),
          });
        }

        // Update per-league stats (merge so joinedAt is preserved)
        final ld = leagueSnaps[i].exists ? leagueSnaps[i].data()! : <String, dynamic>{};
        tx.set(
          leagueRefs[i],
          {
            'playerId': allIds[i],
            'rating': ((ld['rating'] as num?)?.toInt() ?? 0) + pts,
            'wins': ((ld['wins'] as num?)?.toInt() ?? 0) + (isWinner ? 1 : 0),
            'losses': ((ld['losses'] as num?)?.toInt() ?? 0) + (isWinner ? 0 : 1),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  @override
  Future<void> editMatchResult({
    required String leagueId,
    required List<String> oldWinnerIds,
    required List<String> oldLoserIds,
  }) async {
    final allIds = [...oldWinnerIds, ...oldLoserIds];
    final globalRefs = allIds.map((id) => _players.doc(id)).toList();
    final leagueRefs = allIds
        .map((id) => _db
            .collection('leagues')
            .doc(leagueId)
            .collection('players')
            .doc(id))
        .toList();

    // Win=+3, Loss=+1. To flip result:
    //   old winner (now loser): −3+1 = −2 pts, −1 win, +1 loss
    //   old loser  (now winner): −1+3 = +2 pts, +1 win, −1 loss
    const winPts = EloEngine.pointsForWin;
    const lossPts = EloEngine.pointsForLoss;

    await _db.runTransaction((tx) async {
      final globalSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in globalRefs) {
        globalSnaps.add(await tx.get(ref));
      }
      final leagueSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in leagueRefs) {
        leagueSnaps.add(await tx.get(ref));
      }

      for (int i = 0; i < allIds.length; i++) {
        final wasWinner = oldWinnerIds.contains(allIds[i]);
        final ptsDelta = wasWinner ? (-winPts + lossPts) : (-lossPts + winPts);
        final winsDelta = wasWinner ? -1 : 1;
        final lossesDelta = wasWinner ? 1 : -1;

        if (globalSnaps[i].exists) {
          final d = globalSnaps[i].data()!;
          tx.update(globalRefs[i], {
            'rating': ((d['rating'] as num?)?.toInt() ?? 0) + ptsDelta,
            'wins': ((d['wins'] as num?)?.toInt() ?? 0) + winsDelta,
            'losses': ((d['losses'] as num?)?.toInt() ?? 0) + lossesDelta,
          });
        }

        if (leagueSnaps[i].exists) {
          final ld = leagueSnaps[i].data()!;
          tx.update(leagueRefs[i], {
            'rating': ((ld['rating'] as num?)?.toInt() ?? 0) + ptsDelta,
            'wins': ((ld['wins'] as num?)?.toInt() ?? 0) + winsDelta,
            'losses': ((ld['losses'] as num?)?.toInt() ?? 0) + lossesDelta,
          });
        }
      }
    });
  }

  PlayerModel _docToModel(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PlayerModel(
      id: doc.id,
      name: d['name'] as String,
      skillLevel: (d['skillLevel'] as num?)?.toInt() ?? 1,
      gender: d['gender'] == 'female' ? PlayerGender.female : PlayerGender.male,
      rating: (d['rating'] as num?)?.toInt() ?? 0,
      wins: (d['wins'] as num?)?.toInt() ?? 0,
      losses: (d['losses'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }
}
