import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/domain/player_repository.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../schedule/domain/schedule_model.dart';
import '../../data/session_repository.dart';

final sessionControllerProvider = Provider((ref) {
  return SessionController(SessionRepository(), ref.read(playerRepositoryProvider));
});

class SessionController {
  final SessionRepository _sessionRepo;
  final PlayerRepository _playerRepo;

  SessionController(this._sessionRepo, this._playerRepo);

  Future<void> _revertIfCompleted(String leagueId, ScheduledMatch match) async {
    if (!match.isCompleted || match.teamAWon == null) return;
    final winners = match.teamAWon == true ? match.teamA : match.teamB;
    final losers = match.teamAWon == true ? match.teamB : match.teamA;
    await _playerRepo.revertMatchResult(
      leagueId: leagueId,
      winnerIds: winners,
      loserIds: losers,
    );
  }

  /// Deletes a single match, reversing any points it had already awarded.
  Future<void> deleteMatch({
    required String sessionId,
    required String leagueId,
    required ScheduledMatch match,
  }) async {
    await _revertIfCompleted(leagueId, match);
    await _sessionRepo.deleteMatch(sessionId, match.matchNumber);
  }

  /// Deletes an entire session, reversing points for every completed match
  /// in it before removing the session and its matches from Firestore.
  Future<void> deleteSession({
    required String sessionId,
    required String leagueId,
  }) async {
    final matches = await _sessionRepo.getMatches(sessionId);
    for (final match in matches) {
      await _revertIfCompleted(leagueId, match);
    }
    await _sessionRepo.deleteSession(sessionId, leagueId: leagueId);
  }

  /// Changes a completed match's winner, correcting points from the old
  /// result to the new one.
  Future<void> editMatchWinner({
    required String sessionId,
    required String leagueId,
    required ScheduledMatch match,
    required bool newTeamAWon,
  }) async {
    final isFreshCompletion = !match.isCompleted;
    if (match.isCompleted && match.teamAWon == newTeamAWon) {
      // No actual change in outcome — leave points untouched.
    } else if (match.isCompleted && match.teamAWon != null) {
      final oldWinners = match.teamAWon == true ? match.teamA : match.teamB;
      final oldLosers = match.teamAWon == true ? match.teamB : match.teamA;
      await _playerRepo.editMatchResult(
        leagueId: leagueId,
        oldWinnerIds: oldWinners,
        oldLoserIds: oldLosers,
      );
    } else {
      final winners = newTeamAWon ? match.teamA : match.teamB;
      final losers = newTeamAWon ? match.teamB : match.teamA;
      await _playerRepo.recordMatchResult(
        leagueId: leagueId,
        winnerIds: winners,
        loserIds: losers,
      );
    }
    final updated = match.copyWith(
      status: MatchStatus.completed,
      teamAWon: newTeamAWon,
      completedAt: isFreshCompletion ? DateTime.now() : null,
    );
    await _sessionRepo.updateMatch(sessionId, updated);
  }

  /// Adds a brand new scheduled match to a session, assigning the next
  /// available match number.
  Future<void> addMatch({
    required String sessionId,
    required int round,
    required int courtNumber,
    required List<String> teamA,
    required List<String> teamB,
  }) async {
    final existing = await _sessionRepo.getMatches(sessionId);
    final nextNumber = existing.isEmpty
        ? 1
        : existing.map((m) => m.matchNumber).reduce((a, b) => a > b ? a : b) + 1;

    final match = ScheduledMatch(
      matchNumber: nextNumber,
      round: round,
      courtNumber: courtNumber,
      teamA: teamA,
      teamB: teamB,
    );
    await _sessionRepo.addMatch(sessionId, match);
  }

  /// Replaces [oldPlayerId] with [newPlayerId] in a not-yet-completed match.
  Future<void> swapPlayer({
    required String sessionId,
    required ScheduledMatch match,
    required String oldPlayerId,
    required String newPlayerId,
  }) async {
    final teamA = match.teamA.map((id) => id == oldPlayerId ? newPlayerId : id).toList();
    final teamB = match.teamB.map((id) => id == oldPlayerId ? newPlayerId : id).toList();
    await _sessionRepo.updateMatch(
      sessionId,
      ScheduledMatch(
        matchNumber: match.matchNumber,
        round: match.round,
        courtNumber: match.courtNumber,
        teamA: teamA,
        teamB: teamB,
        status: match.status,
        teamAWon: match.teamAWon,
        scoreA: match.scoreA,
        scoreB: match.scoreB,
      ),
    );
  }
}
