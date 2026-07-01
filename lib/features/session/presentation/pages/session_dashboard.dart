import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class SessionDashboard extends ConsumerWidget {
  final String sessionId;
  final String leagueId;

  const SessionDashboard({
    super.key,
    required this.sessionId,
    required this.leagueId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session'),
            Text(
              'ID: ${sessionId.substring(0, 8)}...',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session ID card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Session Active',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            sessionId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Session Tools',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            _ToolButton(
              icon: Icons.calendar_month_rounded,
              label: 'Full Schedule',
              subtitle: 'View and manage the full day match schedule',
              color: const Color(0xFF00695C),
              onTap: () => context.push(
                '/leagues/$leagueId/schedule',
                extra: sessionId,
              ),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.qr_code_2_rounded,
              label: 'Session QR Code',
              subtitle: 'Show QR for players to scan and join session',
              color: cs.primary,
              onTap: () => context.push('/leagues/$leagueId/qr'),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan Player QR',
              subtitle: 'Check in players by scanning their QR code',
              color: cs.tertiary,
              onTap: () => context.push('/scan/camera'),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.sports_rounded,
              label: 'Live Queue',
              subtitle: 'Manage court assignments and match queue',
              color: const Color(0xFF1565C0),
              onTap: () => context.push(
                '/leagues/$leagueId/queue',
                extra: sessionId,
              ),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              subtitle: 'View player rankings for this league',
              color: const Color(0xFFF9A825),
              onTap: () =>
                  context.push('/leagues/$leagueId/leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
