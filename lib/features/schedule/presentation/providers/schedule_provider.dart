import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../session/data/session_repository.dart';
import '../../../session/domain/session_summary.dart';
import '../../domain/schedule_generator.dart';
import '../../domain/schedule_model.dart';

class ScheduleState {
  final List<ScheduledMatch> matches;
  final bool isLoading;

  const ScheduleState({this.matches = const [], this.isLoading = false});

  bool get isEmpty => matches.isEmpty;

  ScheduledMatch? get currentMatch => matches
      .cast<ScheduledMatch?>()
      .firstWhere((m) => m!.isInProgress || m.isScheduled, orElse: () => null);

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
  final String sessionId;
  final _repo = SessionRepository();
  String? _leagueId;

  ScheduleNotifier(this.sessionId)
    : super(const ScheduleState(isLoading: true)) {
    _load();
  }

  /// Hydrates from whatever schedule is already persisted for this session,
  /// so navigating back (or a fresh app launch/hot restart) shows the
  /// generated schedule instead of the generator UI.
  Future<void> _load() async {
    try {
      final matches = await _repo.getMatches(sessionId);
      state = ScheduleState(matches: matches);
    } catch (_) {
      state = const ScheduleState();
    }
  }

  void generate({
    required String leagueId,
    required List<String> playerIds,
    required int courts,
    Map<String, int>? ratings,
    Map<String, String>? genders,
  }) {
    _leagueId = leagueId;
    final matches = ScheduleGenerator.generate(
      playerIds: playerIds,
      courts: courts,
      ratings: ratings,
      genders: genders,
    );
    state = ScheduleState(matches: matches);
    _repo.createSession(leagueId, sessionId, matches).catchError((_) {});
  }

  void startMatch(int matchNumber) {
    final match = state.matches.firstWhere((m) => m.matchNumber == matchNumber);
    final updated = match.copyWith(status: MatchStatus.inProgress);
    state = state.copyWithReplaced(updated);
    _repo.updateMatch(sessionId, updated).catchError((_) {});
  }

  void completeMatch(
    int matchNumber, {
    required bool teamAWon,
    int? scoreA,
    int? scoreB,
  }) {
    final match = state.matches.firstWhere((m) => m.matchNumber == matchNumber);
    final updated = match.copyWith(
      status: MatchStatus.completed,
      teamAWon: teamAWon,
      scoreA: scoreA,
      scoreB: scoreB,
      completedAt: DateTime.now(),
    );
    state = state.copyWithReplaced(updated);
    _repo.updateMatch(sessionId, updated).catchError((_) {});
  }

  void editMatch(
    int matchNumber, {
    required bool teamAWon,
    int? scoreA,
    int? scoreB,
  }) {
    final match = state.matches.firstWhere((m) => m.matchNumber == matchNumber);
    final updated = match.copyWith(
      teamAWon: teamAWon,
      scoreA: scoreA,
      scoreB: scoreB,
    );
    state = state.copyWithReplaced(updated);
    _repo.updateMatch(sessionId, updated).catchError((_) {});
  }

  /// Adds a brand new match, assigning the next available match number.
  void addMatch({
    required int round,
    required int courtNumber,
    required List<String> teamA,
    required List<String> teamB,
  }) {
    final nextNumber = state.matches.isEmpty
        ? 1
        : state.matches
                  .map((m) => m.matchNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final match = ScheduledMatch(
      matchNumber: nextNumber,
      round: round,
      courtNumber: courtNumber,
      teamA: teamA,
      teamB: teamB,
    );
    state = ScheduleState(matches: [...state.matches, match]);
    _repo.addMatch(sessionId, match).catchError((_) {});
  }

  /// Removes a match entirely. Callers are responsible for reversing any
  /// points it had already awarded before calling this.
  void removeMatch(int matchNumber) {
    state = ScheduleState(
      matches: state.matches
          .where((m) => m.matchNumber != matchNumber)
          .toList(),
    );
    _repo.deleteMatch(sessionId, matchNumber).catchError((_) {});
  }

  /// Replaces [oldPlayerId] with [newPlayerId] in a match.
  void swapPlayer(
    int matchNumber, {
    required String oldPlayerId,
    required String newPlayerId,
  }) {
    final match = state.matches.firstWhere((m) => m.matchNumber == matchNumber);
    final updated = ScheduledMatch(
      matchNumber: match.matchNumber,
      round: match.round,
      courtNumber: match.courtNumber,
      teamA: match.teamA
          .map((id) => id == oldPlayerId ? newPlayerId : id)
          .toList(),
      teamB: match.teamB
          .map((id) => id == oldPlayerId ? newPlayerId : id)
          .toList(),
      status: match.status,
      teamAWon: match.teamAWon,
      scoreA: match.scoreA,
      scoreB: match.scoreB,
    );
    state = state.copyWithReplaced(updated);
    _repo.updateMatch(sessionId, updated).catchError((_) {});
  }

  void reset() => state = const ScheduleState(isLoading: false);

  String? get leagueId => _leagueId;
}

final scheduleProvider =
    StateNotifierProvider.family<ScheduleNotifier, ScheduleState, String>(
      (ref, sessionId) => ScheduleNotifier(sessionId),
    );

/// In-memory active session ID per league — survives navigation within the session.
final activeSessionProvider = StateProvider.family<String?, String>(
  (ref, leagueId) => null,
);

/// Streams the Firestore-persisted active session ID for a league.
final activeSessionStreamProvider = StreamProvider.family<String?, String>((
  ref,
  leagueId,
) {
  return SessionRepository().watchActiveSessionId(leagueId);
});

/// Streams matches for a session from Firestore (player read-only view).
final sessionMatchesProvider =
    StreamProvider.family<List<ScheduledMatch>, String>((ref, sessionId) {
      return SessionRepository().watchMatches(sessionId);
    });

/// Fetches past + active sessions for a league, most recent first.
final sessionHistoryProvider =
    FutureProvider.family<List<SessionSummary>, String>((ref, leagueId) {
      return SessionRepository().getSessionsForLeague(leagueId);
    });
