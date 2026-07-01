import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../providers/attendance_provider.dart';

class ScanHubPage extends ConsumerWidget {
  const ScanHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(currentSessionProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Check-in')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scan QR card
            _SectionCard(
              icon: Icons.qr_code_scanner_rounded,
              iconColor: cs.primary,
              title: 'Scan Player QR',
              subtitle: 'Scan a player\'s QR code to check them in',
              buttonLabel: 'Open Scanner',
              onTap: () {
                context.push('/scan/camera');
              },
            ),
            const SizedBox(height: 16),

            // Session management card
            _SectionCard(
              icon: Icons.play_circle_rounded,
              iconColor: const Color(0xFF1565C0),
              title: sessionId == null ? 'Start Session' : 'Session Active',
              subtitle: sessionId == null
                  ? 'Start a session to generate check-in QR codes'
                  : 'Session ID: ${sessionId.substring(0, 8)}...',
              buttonLabel: sessionId == null ? 'Start Session' : 'End Session',
              buttonColor:
                  sessionId == null ? const Color(0xFF1565C0) : Colors.red,
              onTap: () {
                if (sessionId == null) {
                  ref.read(currentSessionProvider.notifier).state =
                      const Uuid().v4();
                } else {
                  ref.read(currentSessionProvider.notifier).state = null;
                }
              },
            ),

            if (sessionId != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.circle,
                                size: 10, color: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          const Text('Live Session',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        sessionId,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Share this session ID with players to check in',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color? buttonColor;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    this.buttonColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = buttonColor ?? iconColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: effectiveColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
