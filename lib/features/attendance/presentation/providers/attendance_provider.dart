import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/attendance_repository_impl.dart';
import '../../domain/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final db = ref.read(databaseProvider);
  return AttendanceRepositoryImpl(db);
});

final currentSessionProvider = StateProvider<String?>((ref) => null);
