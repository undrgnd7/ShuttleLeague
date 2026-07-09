import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../schedule/domain/schedule_model.dart';
import '../../../session/data/session_repository.dart';
import '../../data/player_model.dart';
import 'player_provider.dart';

class MyDashboard {
  final PlayerModel player;
  final ScheduledMatch? lastMatch;
  final bool? lastMatchWon;
  final ScheduledMatch? nextMatch;
  final String? leagueId;
  final String? leagueName;
  final String? sessionId;

  MyDashboard({
    required this.player,
    this.lastMatch,
    this.lastMatchWon,
    this.nextMatch,
    this.leagueId,
    this.leagueName,
    this.sessionId,
  });
}

/// Resolves the current user's linked player (if any) plus their last
/// completed match and next upcoming match in that league's active session.
final myDashboardProvider = FutureProvider<MyDashboard?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final playerId = userDoc.data()?['playerId'] as String?;
  if (playerId == null) return null;

  final player = await ref.read(playerRepositoryProvider).getPlayer(playerId);
  if (player == null) return null;

  final memberships = await FirebaseFirestore.instance
      .collectionGroup('players')
      .where('playerId', isEqualTo: playerId)
      .get();

  for (final doc in memberships.docs) {
    final leagueRef = doc.reference.parent.parent;
    if (leagueRef == null) continue;
    final leagueSnap = await leagueRef.get();
    final activeSessionId = leagueSnap.data()?['activeSessionId'] as String?;
    if (activeSessionId == null) continue;

    final matches = await SessionRepository().getMatches(activeSessionId);
    final myMatches =
        matches.where((m) => m.allPlayers.contains(playerId)).toList();
    if (myMatches.isEmpty) continue;

    ScheduledMatch? next;
    for (final m in myMatches) {
      if (!m.isCompleted) {
        next = m;
        break;
      }
    }

    final completed = myMatches.where((m) => m.isCompleted).toList()
      ..sort((a, b) => b.round.compareTo(a.round));
    final last = completed.isNotEmpty ? completed.first : null;

    bool? lastWon;
    if (last != null && last.teamAWon != null) {
      final onTeamA = last.teamA.contains(playerId);
      lastWon = onTeamA ? last.teamAWon : !last.teamAWon!;
    }

    return MyDashboard(
      player: player,
      lastMatch: last,
      lastMatchWon: lastWon,
      nextMatch: next,
      leagueId: leagueRef.id,
      leagueName: leagueSnap.data()?['name'] as String?,
      sessionId: activeSessionId,
    );
  }

  return MyDashboard(player: player);
});
