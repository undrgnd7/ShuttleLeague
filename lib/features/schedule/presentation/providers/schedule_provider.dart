import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/schedule_generator.dart';
import '../../domain/schedule_model.dart';

class ScheduleState {
  final List<ScheduledMatch> matches;

  const ScheduleState({this.matches = const []});

  bool get isEmpty => matches.isEmpty;

  ScheduledMatch? get currentMatch => matches
      .cast<ScheduledMatch?>()
      .firstWhere((m) => m!.isInProgress || m.isScheduled,
          orElse: () => null);

  int? get currentIndex {
    final m = currentMatch;
    if (m == null) return null;
    return matches.indexOf(m);
  }

  List<ScheduledMatch> get upcoming =>
      matches.where((m) => m.isScheduled).toList();

  List<ScheduledMatch> get completed =>
      matches.where((m) => m.isCompleted).toList();

  ScheduleState copyWithReplaced(ScheduledMatch updated) {
    return ScheduleState(
      matches: matches.map((m) {
        return m.matchNumber == updated.matchNumber ? updated : m;
      }).toList(),
    );
  }
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  ScheduleNotifier() : super(const ScheduleState());

  void generate({
    required List<String> playerIds,
    required int courts,
    Map<String, int>? ratings,
  }) {
    final matches = ScheduleGenerator.generate(
      playerIds: playerIds,
      courts: courts,
      ratings: ratings,
    );
    state = ScheduleState(matches: matches);
  }

  void startMatch(int matchNumber) {
    final match = state.matches.firstWhere((m) => m.matchNumber == matchNumber);
    state = state.copyWithReplaced(
        match.copyWith(status: MatchStatus.inProgress));
  }

  void completeMatch(int matchNumber, {required bool teamAWon}) {
    final match = state.matches.firstWhere((m) => m.matchNumber == matchNumber);
    state = state.copyWithReplaced(match.copyWith(
      status: MatchStatus.completed,
      teamAWon: teamAWon,
    ));
  }

  void reset() => state = const ScheduleState();
}

final scheduleProvider =
    StateNotifierProvider.family<ScheduleNotifier, ScheduleState, String>(
  (ref, sessionId) => ScheduleNotifier(),
);
