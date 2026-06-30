import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/attendance_repository.dart';
import '../providers/attendance_provider.dart';

class CheckInPage extends ConsumerWidget {
  final String leagueId;
  final String sessionId;

  const CheckInPage({
    super.key,
    required this.leagueId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(attendanceRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Check In")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final playerId = const Uuid().v4(); // simulate scanned player

            await repo.checkIn(
              sessionId: sessionId,
              leagueId: leagueId,
              playerId: playerId,
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Checked in successfully")),
            );
          },
          child: const Text("Simulate Scan & Check-in"),
        ),
      ),
    );
  }
}
