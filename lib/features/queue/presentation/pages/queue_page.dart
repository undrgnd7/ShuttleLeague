import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/queue_provider.dart';

class QueuePage extends ConsumerWidget {
  final String sessionId;

  const QueuePage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(queueControllerProvider(sessionId));
    final controller = ref.read(queueControllerProvider(sessionId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Live Queue")),
      body: Column(
        children: [
          const SizedBox(height: 10),

          Text("Queue: ${state.waitingQueue.length} players"),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              controller.joinQueue("P${DateTime.now().millisecond}");
            },
            child: const Text("Add Player to Queue"),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {
              controller.startNextMatch(1);
            },
            child: const Text("Start Next Match (Court 1)"),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {
              controller.endMatch(
                courtNumber: 1,
                winners: ["P1", "P2"],
                losers: ["P3", "P4"],
              );
            },
            child: const Text("End Match (Simulate)"),
          ),

          const Divider(),

          Expanded(
            child: ListView(
              children: [
                Text("Waiting Queue:"),
                ...state.waitingQueue.map((p) => ListTile(title: Text(p))),

                const SizedBox(height: 20),

                Text("Courts:"),
                ...state.courtAssignments.entries.map(
                  (e) => ListTile(
                    title: Text("Court ${e.key}"),
                    subtitle: Text("Match: ${e.value}"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
