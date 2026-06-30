import 'package:flutter/material.dart';

class SessionDashboard extends StatelessWidget {
  final String sessionId;
  final String leagueId;

  const SessionDashboard({
    super.key,
    required this.sessionId,
    required this.leagueId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Session Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Session ID: $sessionId"),
            Text("League ID: $leagueId"),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                // Start QR scan for attendance
                Navigator.pushNamed(context, "/scan");
              },
              child: const Text("Scan Player QR"),
            ),

            ElevatedButton(
              onPressed: () {
                // Trigger match generation
              },
              child: const Text("Generate Matches"),
            ),

            ElevatedButton(
              onPressed: () {
                // Open live queue
              },
              child: const Text("Open Live Queue"),
            ),

            ElevatedButton(
              onPressed: () {
                // View leaderboard
              },
              child: const Text("Leaderboard"),
            ),
          ],
        ),
      ),
    );
  }
}
