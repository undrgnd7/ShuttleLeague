import 'package:cloud_firestore/cloud_firestore.dart';

import '../../schedule/domain/schedule_model.dart';

class SessionRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  CollectionReference<Map<String, dynamic>> get _leagues =>
      _db.collection('leagues');

  /// Write full schedule to Firestore and mark league as having an active session.
  Future<void> createSession(
    String leagueId,
    String sessionId,
    List<ScheduledMatch> matches,
  ) async {
    final batch = _db.batch();
    batch.set(_sessions.doc(sessionId), {
      'leagueId': leagueId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final match in matches) {
      batch.set(
        _sessions.doc(sessionId).collection('matches').doc('${match.matchNumber}'),
        match.toMap(),
      );
    }
    batch.update(_leagues.doc(leagueId), {'activeSessionId': sessionId});
    await batch.commit();
  }

  /// Update a single match in Firestore (called on start / complete / edit).
  Future<void> updateMatch(String sessionId, ScheduledMatch match) {
    return _sessions
        .doc(sessionId)
        .collection('matches')
        .doc('${match.matchNumber}')
        .update(match.toMap());
  }

  /// Stream all matches for a session, ordered by matchNumber.
  Stream<List<ScheduledMatch>> watchMatches(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection('matches')
        .orderBy('matchNumber')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ScheduledMatch.fromMap(d.data())).toList());
  }

  /// Stream the active session ID stored on the league document.
  Stream<String?> watchActiveSessionId(String leagueId) {
    return _leagues.doc(leagueId).snapshots().map(
          (doc) => doc.data()?['activeSessionId'] as String?,
        );
  }

  /// Clear the active session from the league (end of session).
  Future<void> endSession(String leagueId, String sessionId) async {
    final batch = _db.batch();
    batch.update(_sessions.doc(sessionId), {'status': 'ended'});
    batch.update(
      _leagues.doc(leagueId),
      {'activeSessionId': FieldValue.delete()},
    );
    await batch.commit();
  }
}
