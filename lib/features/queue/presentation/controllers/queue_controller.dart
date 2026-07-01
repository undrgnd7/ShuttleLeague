import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../features/match/domain/match_generator.dart';
import '../../domain/live_session_state.dart';

class QueueController extends StateNotifier<LiveSessionState> {
  QueueController(String sessionId)
      : super(
          LiveSessionState(
            sessionId: sessionId,
            waitingQueue: [],
            activeMatches: [],
          ),
        );

  void joinQueue(String playerId) {
    if (state.waitingQueue.contains(playerId)) return;
    final inActiveMatch = state.activeMatches
        .any((m) => m.teamA.contains(playerId) || m.teamB.contains(playerId));
    if (inActiveMatch) return;

    state = state.copyWith(
      waitingQueue: [...state.waitingQueue, playerId],
    );
  }

  void removeFromQueue(String playerId) {
    state = state.copyWith(
      waitingQueue: state.waitingQueue.where((p) => p != playerId).toList(),
    );
  }

  /// Start a match with 4 players from queue. Pass optional [ratings] map
  /// for ELO-balanced pairing.
  void startNextMatch({Map<String, int>? ratings}) {
    if (state.waitingQueue.length < 4) return;

    final next4 = state.waitingQueue.take(4).toList();
    final remaining = state.waitingQueue.skip(4).toList();

    final pairings = MatchGenerator.generateDoubles(next4, ratings: ratings);
    if (pairings.isEmpty) return;

    final pair = pairings.first;
    final courtNumber =
        (state.activeMatches.isEmpty ? 1 : state.activeMatches.last.courtNumber + 1);

    final match = ActiveMatch(
      matchId: const Uuid().v4(),
      courtNumber: courtNumber,
      teamA: pair[0],
      teamB: pair[1],
    );

    state = state.copyWith(
      waitingQueue: remaining,
      activeMatches: [...state.activeMatches, match],
    );
  }

  /// End a match — winning team goes back to front of queue, losers to end.
  void endMatch({
    required String matchId,
    required bool teamAWon,
  }) {
    final match =
        state.activeMatches.firstWhere((m) => m.matchId == matchId);

    final winners = teamAWon ? match.teamA : match.teamB;
    final losers = teamAWon ? match.teamB : match.teamA;

    final newQueue = [
      ...winners,
      ...state.waitingQueue,
      ...losers,
    ];

    state = state.copyWith(
      activeMatches:
          state.activeMatches.where((m) => m.matchId != matchId).toList(),
      waitingQueue: newQueue,
    );
  }

  void initWithPlayers(List<String> playerIds) {
    state = state.copyWith(waitingQueue: playerIds);
  }
}
