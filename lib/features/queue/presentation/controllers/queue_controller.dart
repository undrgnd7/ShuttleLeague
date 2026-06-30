import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/live_session_state.dart';

class QueueController extends StateNotifier<LiveSessionState> {
  QueueController(String sessionId)
      : super(
          LiveSessionState(
            sessionId: sessionId,
            waitingQueue: [],
            activeMatchId: null,
            courtAssignments: {},
          ),
        );

  /// Add player into queue
  void joinQueue(String playerId) {
    final updated = [...state.waitingQueue, playerId];

    state = state.copyWith(waitingQueue: updated);
  }

  /// Assign next match to court
  void startNextMatch(int courtNumber) {
    if (state.waitingQueue.length < 4) return;

    final players = state.waitingQueue.take(4).toList();
    final remaining = state.waitingQueue.skip(4).toList();

    final newAssignments = Map<int, String>.from(state.courtAssignments);
    newAssignments[courtNumber] = "MATCH_${DateTime.now().millisecondsSinceEpoch}";

    state = state.copyWith(
      waitingQueue: remaining,
      activeMatchId: newAssignments[courtNumber],
      courtAssignments: newAssignments,
    );
  }

  /// End match and rotate players
  void endMatch({
    required int courtNumber,
    required List<String> winners,
    required List<String> losers,
  }) {
    final queue = [...state.waitingQueue];

    // Winners stay in rotation
    queue.insertAll(0, winners);

    // Losers go back to queue end
    queue.addAll(losers);

    final updatedCourts = Map<int, String>.from(state.courtAssignments);
    updatedCourts.remove(courtNumber);

    state = state.copyWith(
      waitingQueue: queue,
      courtAssignments: updatedCourts,
      activeMatchId: null,
    );
  }
}
