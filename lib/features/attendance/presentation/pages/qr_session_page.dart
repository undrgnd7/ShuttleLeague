import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/attendance_provider.dart';

class QRSessionPage extends ConsumerWidget {
  final String leagueId;

  const QRSessionPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(currentSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('QR Session')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (sessionId == null)
              ElevatedButton(
                onPressed: () {
                  final newSession = const Uuid().v4();
                  ref.read(currentSessionProvider.notifier).state =
                      newSession;
                },
                child: const Text("Start Session"),
              )
            else ...[
              Text(
                "Session Active",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              SelectableText(
                "QR DATA:\n$leagueId|$sessionId",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                "Players scan this QR to check in",
              ),
            ]
          ],
        ),
      ),
    );
  }
}
