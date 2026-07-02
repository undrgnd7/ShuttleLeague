import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../domain/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AppDatabase db;

  AttendanceRepositoryImpl(this.db);

  @override
  Future<String> createSession(String leagueId) async {
    final sessionId = const Uuid().v4();

    return sessionId;
  }

  @override
  Future<void> checkIn({
    required String sessionId,
    required String leagueId,
    required String playerId,
  }) async {
    await db.into(db.attendance).insert(
      AttendanceCompanion.insert(
        id: const Uuid().v4(),
        leagueId: leagueId,
        playerId: playerId,
        sessionId: sessionId,
        checkInTime: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  @override
  Future<List<String>> getCheckedInPlayers(String sessionId) async {
    final rows = await (db.select(db.attendance)
          ..where((a) => a.sessionId.equals(sessionId)))
        .get();

    return rows.map((e) => e.playerId).toList();
  }
}
