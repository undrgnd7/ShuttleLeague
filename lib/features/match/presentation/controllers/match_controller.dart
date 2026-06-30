import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/match_repository.dart';
import '../../../attendance/data/attendance_repository_impl.dart';

class MatchController {
  final MatchRepository matchRepo;
  final AttendanceRepositoryImpl attendanceRepo;
  final Ref ref;

  MatchController({
    required this.matchRepo,
    required this.attendanceRepo,
    required this.ref,
  });

  Future<void> generateForSession({
    required String leagueId,
    required String sessionId,
  }) async {
    final playerIds =
        await attendanceRepo.getCheckedInPlayers(sessionId);

    await matchRepo.generateMatches(
      leagueId: leagueId,
      sessionId: sessionId,
      playerIds: playerIds,
    );
  }
}
