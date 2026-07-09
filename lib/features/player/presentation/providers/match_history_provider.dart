import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../schedule/domain/schedule_model.dart';

class PlayerMatchEntry {
  final ScheduledMatch match;
  final String sessionId;
  final String leagueId;
  final String leagueName;
  final bool? won;
  final DateTime sortTime;

  PlayerMatchEntry({
    required this.match,
    required this.sessionId,
    required this.leagueId,
    required this.leagueName,
    required this.won,
    required this.sortTime,
  });
}

/// All completed matches a player has played, across every league, most
/// recently completed first.
final playerMatchHistoryProvider =
    FutureProvider.family<List<PlayerMatchEntry>, String>((ref, playerId) async {
  final db = FirebaseFirestore.instance;

  final teamASnap = await db
      .collectionGroup('matches')
      .where('teamA', arrayContains: playerId)
      .get();
  final teamBSnap = await db
      .collectionGroup('matches')
      .where('teamB', arrayContains: playerId)
      .get();

  final docsByPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final d in teamASnap.docs) {
    docsByPath[d.reference.path] = d;
  }
  for (final d in teamBSnap.docs) {
    docsByPath[d.reference.path] = d;
  }

  final sessionCache = <String, Map<String, dynamic>?>{};
  final leagueNameCache = <String, String>{};
  final entries = <PlayerMatchEntry>[];

  for (final doc in docsByPath.values) {
    final match = ScheduledMatch.fromMap(doc.data());
    if (!match.isCompleted) continue;

    final sessionRef = doc.reference.parent.parent;
    if (sessionRef == null) continue;
    final sessionId = sessionRef.id;

    if (!sessionCache.containsKey(sessionId)) {
      final snap = await sessionRef.get();
      sessionCache[sessionId] = snap.data();
    }
    final sessionData = sessionCache[sessionId];
    if (sessionData == null) continue;

    final leagueId = sessionData['leagueId'] as String? ?? '';
    final sessionCreatedAt = (sessionData['createdAt'] as Timestamp?)?.toDate();

    if (!leagueNameCache.containsKey(leagueId)) {
      final leagueSnap = await db.collection('leagues').doc(leagueId).get();
      leagueNameCache[leagueId] = leagueSnap.data()?['name'] as String? ?? 'League';
    }

    bool? won;
    if (match.teamAWon != null) {
      final onTeamA = match.teamA.contains(playerId);
      won = onTeamA ? match.teamAWon : !match.teamAWon!;
    }

    entries.add(PlayerMatchEntry(
      match: match,
      sessionId: sessionId,
      leagueId: leagueId,
      leagueName: leagueNameCache[leagueId]!,
      won: won,
      sortTime: match.completedAt ??
          sessionCreatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0),
    ));
  }

  entries.sort((a, b) => b.sortTime.compareTo(a.sortTime));
  return entries;
});
