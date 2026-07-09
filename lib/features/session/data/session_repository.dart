import 'package:cloud_firestore/cloud_firestore.dart';

import '../../schedule/domain/schedule_model.dart';
import '../domain/session_summary.dart';

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

  /// Adds a brand new match to a session (admin-created, outside the
  /// generated schedule).
  Future<void> addMatch(String sessionId, ScheduledMatch match) {
    return _sessions
        .doc(sessionId)
        .collection('matches')
        .doc('${match.matchNumber}')
        .set(match.toMap());
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

  /// One-shot fetch of all matches for a session, ordered by matchNumber.
  Future<List<ScheduledMatch>> getMatches(String sessionId) async {
    final snap = await _sessions
        .doc(sessionId)
        .collection('matches')
        .orderBy('matchNumber')
        .get();
    return snap.docs.map((d) => ScheduledMatch.fromMap(d.data())).toList();
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

  /// Lists all sessions (active and ended) for a league, most recent first.
  Future<List<SessionSummary>> getSessionsForLeague(String leagueId) async {
    final snap = await _sessions
        .where('leagueId', isEqualTo: leagueId)
        .orderBy('createdAt', descending: true)
        .get();

    final summaries = <SessionSummary>[];
    for (final doc in snap.docs) {
      final matchesRef = doc.reference.collection('matches');
      final total = (await matchesRef.count().get()).count ?? 0;
      final done = (await matchesRef
                  .where('status', isEqualTo: 'completed')
                  .count()
                  .get())
              .count ??
          0;
      final d = doc.data();
      summaries.add(SessionSummary(
        id: doc.id,
        leagueId: leagueId,
        status: d['status'] as String? ?? 'ended',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        matchCount: total,
        completedCount: done,
      ));
    }
    return summaries;
  }

  /// Deletes a single match from a session.
  Future<void> deleteMatch(String sessionId, int matchNumber) {
    return _sessions
        .doc(sessionId)
        .collection('matches')
        .doc('$matchNumber')
        .delete();
  }

  /// Deletes a session and every match under it. If it was the league's
  /// active session, clears that reference too.
  Future<void> deleteSession(String sessionId, {required String leagueId}) async {
    final matchesSnap =
        await _sessions.doc(sessionId).collection('matches').get();

    final batch = _db.batch();
    for (final doc in matchesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_sessions.doc(sessionId));
    await batch.commit();

    final leagueDoc = await _leagues.doc(leagueId).get();
    if (leagueDoc.data()?['activeSessionId'] == sessionId) {
      await _leagues.doc(leagueId).update({
        'activeSessionId': FieldValue.delete(),
      });
    }
  }
}
