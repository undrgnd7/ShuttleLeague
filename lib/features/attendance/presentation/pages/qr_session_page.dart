import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../providers/attendance_provider.dart';

class QRSessionPage extends ConsumerWidget {
  final String leagueId;

  const QRSessionPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(currentSessionProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Session QR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: sessionId == null
              ? _StartSessionView(
                  onStart: () {
                    ref.read(currentSessionProvider.notifier).state =
                        const Uuid().v4();
                  },
                )
              : _ActiveSessionView(
                  leagueId: leagueId,
                  sessionId: sessionId,
                  onEnd: () {
                    ref.read(currentSessionProvider.notifier).state = null;
                  },
                ),
        ),
      ),
    );
  }
}

class _StartSessionView extends StatelessWidget {
  final VoidCallback onStart;
  const _StartSessionView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.qr_code_2_rounded,
              size: 56, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 24),
        Text('No Active Session',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Start a session to generate a QR code players can scan to check in.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Session'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ActiveSessionView extends StatelessWidget {
  final String leagueId;
  final String sessionId;
  final VoidCallback onEnd;

  const _ActiveSessionView({
    required this.leagueId,
    required this.sessionId,
    required this.onEnd,
  });

  String get _qrData => '$leagueId|$sessionId';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.circle, size: 8, color: Colors.green),
            ),
            const SizedBox(width: 6),
            Text('Session Active',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                    fontSize: 14)),
          ],
        ),
        const SizedBox(height: 20),

        // QR code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: _qrData,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: cs.primary,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Players scan this to join the session',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // Session ID display
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: sessionId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Session ID copied'),
                  duration: Duration(seconds: 2)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sessionId.substring(0, 16).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy_rounded, size: 14, color: cs.outline),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        OutlinedButton.icon(
          onPressed: onEnd,
          icon: const Icon(Icons.stop_circle_rounded),
          label: const Text('End Session'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            side: BorderSide(color: cs.error),
          ),
        ),
      ],
    );
  }
}
